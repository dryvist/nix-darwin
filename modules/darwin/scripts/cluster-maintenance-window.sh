# shellcheck shell=bash
# One reconcile pass: make the shared maintenance window match whether this
# host is clustered right now.
#
# A maintenance window is how the estate is told "hands off this host". Opening
# one used to be an operator step, which means it was skipped exactly when it
# mattered — during an unattended cluster cycle nobody was watching. So the
# cluster machinery opens and closes its own window, with no human in the loop.
#
# A RECONCILER, NOT A HOOK. It is not called on the link-up or link-down edge;
# it runs on a timer and drives the window toward live cluster state every
# tick. That choice buys two properties an edge hook cannot have:
#
#   1. It CANNOT delay a rank start or a teardown. It is not on that path at
#      all. Protection domains are physics and the cluster's timing belongs to
#      the watcher; a window is coordination, and coordination must never be
#      able to hold the physics up. Nothing here blocks anything.
#   2. It is self-healing. A window left open by a crashed process, a close
#      that failed because the network was down, a create that never landed —
#      all converge on the next tick. An edge hook gets exactly one chance at
#      each transition and silently loses the ones it misses.
#
# Everything here is BEST EFFORT AND LOUD. Every tick logs the decision it
# made, and every failed call logs why; nothing is retried forever and nothing
# fails silently. The window is not a lock and this script cannot stop anyone.
#
# Consumed environment:
#   MLX_CLUSTER_RANK_LIVE_BIN     detector; see ./mlx-cluster-rank-live.sh
#   VIKUNJA_API_URL               API base, e.g. https://host/api/v1 — supplied
#                                 by the secret-zero env file, alongside the
#                                 secret backend address, so no internal
#                                 hostname is baked into this repository
#   VIKUNJA_USERNAME              service account (default svc-mcp-rw)
#   VIKUNJA_PASSWORD              its password, injected by the secret helper
#   MLX_CLUSTER_WINDOW_PROJECT    project holding maintenance windows
#   MLX_CLUSTER_WINDOW_LABEL      label applied to the task (resolved by title)
#   MLX_CLUSTER_WINDOW_TITLE      this host's FQDN — the window's identity
#   MLX_CLUSTER_WINDOW_HOURS      rolling window length, refreshed each tick
#   MLX_CLUSTER_WINDOW_STATE_FILE where the open window's task id is kept
#   MLX_CLUSTER_WINDOW_ATTEMPTS   attempts per API call (default 2)
#   MLX_CLUSTER_CURL_BIN          curl path (default /usr/bin/curl — the Apple
#                                 platform binary; a nix-store curl is denied
#                                 LAN access in a GUI launchd context)

api_url="${VIKUNJA_API_URL:-}"
username="${VIKUNJA_USERNAME:-svc-mcp-rw}"
password="${VIKUNJA_PASSWORD:-}"
project="${MLX_CLUSTER_WINDOW_PROJECT:?MLX_CLUSTER_WINDOW_PROJECT not set}"
label_title="${MLX_CLUSTER_WINDOW_LABEL:-maintenance}"
title="${MLX_CLUSTER_WINDOW_TITLE:?MLX_CLUSTER_WINDOW_TITLE not set}"
hours="${MLX_CLUSTER_WINDOW_HOURS:-6}"
state_file="${MLX_CLUSTER_WINDOW_STATE_FILE:?MLX_CLUSTER_WINDOW_STATE_FILE not set}"
attempts="${MLX_CLUSTER_WINDOW_ATTEMPTS:-2}"
curl_bin="${MLX_CLUSTER_CURL_BIN:-/usr/bin/curl}"
rank_live_bin="${MLX_CLUSTER_RANK_LIVE_BIN:?MLX_CLUSTER_RANK_LIVE_BIN not set}"

log() { echo "cluster-maintenance-window: $*"; }
warn() { echo "cluster-maintenance-window: WARN $*" >&2; }

mkdir -p "$(dirname "$state_file")"

# One API call, bounded. Two attempts by default rather than a retry loop: the
# whole reconcile repeats on the next tick anyway, so the only failure an inner
# loop can usefully absorb is a single dropped connection. Anything longer-lived
# is reported and left to the next tick, which is the real retry.
#
# $1 = method, $2 = path (appended to the API base), $3 = JSON body ("" = none).
# Prints the response body on success; returns nonzero after the last attempt.
api() {
  local method="$1" path="$2" body="${3:-}" i=1 out=""
  while [ "$i" -le "$attempts" ]; do
    if [ -n "$body" ]; then
      out="$(printf '%s' "$body" | "$curl_bin" -sSf --max-time 20 -X "$method" \
        -H "Authorization: Bearer $jwt" -H 'Content-Type: application/json' \
        --data-binary @- "$api_url$path" 2>&1)" && {
        printf '%s' "$out"
        return 0
      }
    else
      out="$("$curl_bin" -sSf --max-time 20 -X "$method" \
        -H "Authorization: Bearer $jwt" "$api_url$path" 2>&1)" && {
        printf '%s' "$out"
        return 0
      }
    fi
    warn "$method $path attempt $i/$attempts failed: ${out:0:200}"
    i=$((i + 1))
  done
  return 1
}

recorded_id() {
  [ -f "$state_file" ] || return 1
  local id
  id="$(cat "$state_file" 2> /dev/null || true)"
  case "$id" in
    '' | *[!0-9]*) return 1 ;;
    *) printf '%s' "$id" ;;
  esac
}

# --- what is this host doing right now? -------------------------------------
# Asked FIRST, and asked of launchd, so the branch below is driven by measured
# state and not by what the state file remembers. rc 2 (no GUI launchd domain)
# is folded into "not clustered" here — a rank cannot run without that domain —
# and the fold is logged rather than assumed.
rank_rc=0
"$rank_live_bin" || rank_rc=$?
case "$rank_rc" in
  0) clustered=yes ;;
  1) clustered=no ;;
  *)
    clustered=no
    log "cluster state UNDETERMINED (rc=$rank_rc); treating this host as not clustered — a rank cannot run without a GUI launchd domain"
    ;;
esac

open_id="$(recorded_id || true)"

# Nothing to do and nothing to say to the API: the common steady state on an
# unclustered host. Reported anyway — one line per tick is what makes "the
# reconciler is alive and deciding" observable, and a job that exits 0 in
# silence is indistinguishable from one that is quietly broken.
if [ "$clustered" = no ] && [ -z "$open_id" ]; then
  log "not clustered, no window open — nothing to do"
  exit 0
fi

# --- authenticate (only once there is real work) ----------------------------
[ -n "$api_url" ] || {
  warn "VIKUNJA_API_URL not set; cannot reconcile the window (clustered=$clustered, open window=${open_id:-none})"
  exit 0
}
[ -n "$password" ] || {
  warn "no service-account password in the environment; cannot reconcile the window (clustered=$clustered, open window=${open_id:-none})"
  exit 0
}

jwt=""
login_body="$(jq -n --arg u "$username" --arg p "$password" '{username:$u, password:$p}')"
if ! jwt="$(api POST /login "$login_body" | jq -re '.token')"; then
  warn "login as $username failed; window NOT reconciled this tick (clustered=$clustered, open window=${open_id:-none}). Nothing else is affected — the cluster does not wait on this."
  exit 0
fi

# --- reconcile --------------------------------------------------------------
# BSD form first (this runs on macOS), GNU form as the fallback so the same
# code path is exercisable in a coreutils-only test sandbox. Not a seam and not
# an option: one expression, both dates, nothing to configure or get wrong.
now_plus_hours() {
  local epoch
  epoch=$(($(date -u +%s) + hours * 3600))
  date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null ||
    date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ
}

if [ "$clustered" = yes ]; then
  due="$(now_plus_hours)"
  if [ -n "$open_id" ]; then
    # ROLLING EXPIRY. The due date is pushed out every tick rather than set
    # once to a guessed session length: a window that outlives the work is a
    # false hands-off flag on a free host, and one that expires mid-session is
    # worse. Refreshing is also what makes a crashed reconciler self-limiting —
    # the window simply stops being extended and ages out.
    if api POST "/tasks/$open_id" "$(jq -n --arg d "$due" '{due_date:$d}')" > /dev/null; then
      log "clustered — refreshed window task $open_id, now due $due"
    else
      # Most likely the task was deleted or closed by hand. Drop the id so the
      # next tick opens a fresh window instead of refreshing a ghost forever.
      warn "could not refresh window task $open_id; forgetting it so the next tick opens a new window"
      rm -f "$state_file"
    fi
    exit 0
  fi

  description="Opened automatically by the MLX cluster maintenance-window reconciler on this host, and closed automatically at cluster teardown. While this window is open the host is running a cluster rank: do not rebuild, reboot, or converge it."
  new_id=""
  if ! new_id="$(api PUT "/projects/$project/tasks" \
    "$(jq -n --arg t "$title" --arg d "$description" --arg due "$due" \
      '{title:$t, description:$d, due_date:$due}')" | jq -re '.id')"; then
    warn "clustered but could NOT open a maintenance window; retrying next tick. The cluster is unaffected."
    exit 0
  fi
  printf '%s\n' "$new_id" > "$state_file"
  log "clustered — opened window task $new_id ($title), due $due"

  # Label last, and never fatal: an unlabelled window is still a window, and
  # failing the whole reconcile over a label would leave the id unrecorded and
  # open a duplicate window every tick.
  label_id=""
  if label_id="$(api GET /labels '' | jq -re --arg n "$label_title" '.[] | select(.title == $n) | .id' | head -n1)" &&
    [ -n "$label_id" ]; then
    if api PUT "/tasks/$new_id/labels" "$(jq -n --argjson l "$label_id" '{label_id:$l}')" > /dev/null; then
      log "labelled window task $new_id '$label_title'"
    else
      warn "could not apply label '$label_title' to window task $new_id (window is open regardless)"
    fi
  else
    warn "could not resolve a label titled '$label_title' (window task $new_id is open and unlabelled)"
  fi
  exit 0
fi

# Not clustered, and a window is on the books: close it.
if api POST "/tasks/$open_id" '{"done":true}' > /dev/null; then
  rm -f "$state_file"
  log "not clustered — closed window task $open_id"
else
  warn "not clustered but could NOT close window task $open_id; keeping the id so the next tick retries"
fi
