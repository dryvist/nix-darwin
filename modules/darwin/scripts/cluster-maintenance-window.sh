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
# CLUSTERED is the rebuild gate's definition (see cluster-rebuild-gate.sh): a
# rank is live, or the link is up and the peer reports armed. Anything the gate
# would refuse on counts as clustered here, so unreadable state keeps the window
# open.
#
# Everything here is BEST EFFORT AND LOUD. Every tick logs the decision it
# made, and every failed call logs why; nothing is retried forever and nothing
# fails silently. The window is not a lock and this script cannot stop anyone.
#
# Consumed environment:
#   MLX_CLUSTER_RANK_LIVE_BIN     detector; see ./mlx-cluster-rank-live.sh
#   CLUSTER_USER_HOME             primary user's home, holding the link and
#                                 peer state files (the rebuild gate's value)
#   VIKUNJA_API_URL               API base, e.g. https://host/api/v1 — supplied
#                                 by the launcher, so no internal hostname is
#                                 baked into this repository
#   VIKUNJA_API_TOKEN             bearer token of the window's service account,
#                                 supplied by the launcher
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
api_token="${VIKUNJA_API_TOKEN:-}"
project="${MLX_CLUSTER_WINDOW_PROJECT:?MLX_CLUSTER_WINDOW_PROJECT not set}"
label_title="${MLX_CLUSTER_WINDOW_LABEL:-maintenance}"
title="${MLX_CLUSTER_WINDOW_TITLE:?MLX_CLUSTER_WINDOW_TITLE not set}"
hours="${MLX_CLUSTER_WINDOW_HOURS:-6}"
state_file="${MLX_CLUSTER_WINDOW_STATE_FILE:?MLX_CLUSTER_WINDOW_STATE_FILE not set}"
attempts="${MLX_CLUSTER_WINDOW_ATTEMPTS:-2}"
curl_bin="${MLX_CLUSTER_CURL_BIN:-/usr/bin/curl}"
rank_live_bin="${MLX_CLUSTER_RANK_LIVE_BIN:?MLX_CLUSTER_RANK_LIVE_BIN not set}"
user_home="${CLUSTER_USER_HOME:?CLUSTER_USER_HOME not set}"
state_dir="$user_home/Library/Application Support/mlx-cluster"
link_file="$state_dir/link-state"
peer_file="$state_dir/peer-state.json"

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
        -H @<(printf 'Authorization: Bearer %s\n' "$api_token") -H 'Content-Type: application/json' \
        --data-binary @- "$api_url$path" 2>&1)" && {
        printf '%s' "$out"
        return 0
      }
    else
      out="$("$curl_bin" -sSf --max-time 20 -X "$method" \
        -H @<(printf 'Authorization: Bearer %s\n' "$api_token") "$api_url$path" 2>&1)" && {
        printf '%s' "$out"
        return 0
      }
    fi
    warn "$method $path attempt $i/$attempts failed: ${out:0:200}"
    i=$((i + 1))
  done
  return 1
}

# Vikunja blanks any field a POST omits, so every update is read-modify-write:
# GET the task, apply one edit, POST the whole object back. The select refuses a
# response that is not the task asked for, so nothing partial is ever posted.
# $1 = task id, $2 = jq edit, $3 = value the edit reads as $due.
update_task() {
  local id="$1" edit="$2" current body
  current="$(api GET "/tasks/$id")" || return 1
  body="$(printf '%s' "$current" | jq -ce --argjson id "$id" --arg due "${3:-}" \
    "select(.id == \$id) | $edit")" || return 1
  [ -n "$body" ] || return 1
  api POST "/tasks/$id" "$body" > /dev/null
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

# The link half of the rebuild gate, read as the gate reads it: no link-state is
# no link, `down` is free, `up` with an armed peer is clustered. Every state the
# gate refuses on counts as clustered here. Sets $why; returns 0 when clustered.
object_re='^[[:space:]]*[{].*[}][[:space:]]*$'
armed_key='"armed"'
armed_re='"armed"[[:space:]]*:[[:space:]]*(true|false)[[:space:]]*[,}]'

link_clustered() {
  local link_state peer_state stripped
  if [ ! -e "$link_file" ] && [ ! -L "$link_file" ]; then why="link-state absent"; return 1; fi
  if ! link_state="$(< "$link_file")"; then why="link-state unreadable"; return 0; fi
  case "$link_state" in
    down) why="link-state down"; return 1 ;;
    up) ;;
    *) why="link-state holds an unrecognised value"; return 0 ;;
  esac
  if ! peer_state="$(< "$peer_file")"; then why="link-state up, peer-state.json unreadable"; return 0; fi
  # Bash built-ins, as the gate parses it: shape-checked, not JSON-validated.
  stripped="${peer_state//"$armed_key"/}"
  if ! [[ $peer_state =~ $object_re ]] || (( ${#peer_state} - ${#stripped} != ${#armed_key} )) ||
    ! [[ $peer_state =~ $armed_re ]]; then
    why="link-state up, peer-state.json does not hold one armed flag"; return 0
  fi
  if [ "${BASH_REMATCH[1]}" = true ]; then why="link-state up, peer armed"; return 0; fi
  why="link-state up, peer not armed"; return 1
}

# --- is this host clustered right now? (rank first, then link, as the gate) ---
# rc 2 (no GUI launchd domain) counts as "rank not live", and the fold is logged.
rank_rc=0
"$rank_live_bin" || rank_rc=$?
clustered=no
why=""
case "$rank_rc" in
  0) clustered=yes; why="rank agent live" ;;
  1) ;;
  *) log "rank state UNDETERMINED (rc=$rank_rc); treating the rank as not live and reading the link" ;;
esac
if [ "$clustered" = no ]; then
  if [ ! -d "$user_home" ]; then
    clustered=yes; why="CLUSTER_USER_HOME is not a directory, so cluster state cannot be read"
  elif link_clustered; then
    clustered=yes
  fi
fi

open_id="$(recorded_id || true)"

# Nothing to do and nothing to say to the API: the common steady state on an
# unclustered host. Reported anyway — one line per tick is what makes "the
# reconciler is alive and deciding" observable, and a job that exits 0 in
# silence is indistinguishable from one that is quietly broken.
if [ "$clustered" = no ] && [ -z "$open_id" ]; then
  log "not clustered ($why); no window open, nothing to do"
  exit 0
fi

# --- credentials, only once there is real work ------------------------------
[ -n "$api_url" ] || {
  warn "VIKUNJA_API_URL not set; cannot reconcile the window (clustered=$clustered, open window=${open_id:-none})"
  exit 0
}
[ -n "$api_token" ] || {
  warn "no VIKUNJA_API_TOKEN in the environment; cannot reconcile the window (clustered=$clustered, open window=${open_id:-none})"
  exit 0
}

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
    # done = false reopens a window closed by hand while the host is still
    # clustered: the window tracks the cluster, not the last click.
    if update_task "$open_id" ".due_date = \$due | .done = false" "$due"; then
      log "clustered ($why); refreshed window task $open_id, now due $due"
    elif [ "$("$curl_bin" -s -o /dev/null -w '%{http_code}' --max-time 20 \
      -H @<(printf 'Authorization: Bearer %s\n' "$api_token") "$api_url/tasks/$open_id" || true)" = 404 ]; then
      # Deleted by hand. Drop the id so the next tick opens a fresh window.
      warn "window task $open_id no longer exists; forgetting it so the next tick opens a new window"
      rm -f "$state_file"
    else
      # A transient failure keeps the id: forgetting it would open a duplicate.
      warn "could not refresh window task $open_id; keeping the id so the next tick retries"
    fi
    exit 0
  fi

  description="Opened automatically by the MLX cluster maintenance-window reconciler on this host, and closed automatically at cluster teardown. While this window is open the host is clustered (a rank is live, or the cluster link is up and armed): do not rebuild, reboot, or converge it."
  new_id=""
  if ! new_id="$(api PUT "/projects/$project/tasks" \
    "$(jq -n --arg t "$title" --arg d "$description" --arg due "$due" \
      '{title:$t, description:$d, due_date:$due}')" | jq -re '.id')"; then
    warn "clustered but could NOT open a maintenance window; retrying next tick. The cluster is unaffected."
    exit 0
  fi
  printf '%s\n' "$new_id" > "$state_file"
  log "clustered ($why); opened window task $new_id ($title), due $due"

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

# Not clustered, and a window is on the books: close it, read-modify-write as the
# refresh is, so the description survives.
if update_task "$open_id" '.done = true'; then
  rm -f "$state_file"
  log "not clustered ($why); closed window task $open_id"
else
  warn "not clustered but could NOT close window task $open_id; keeping the id so the next tick retries"
fi
