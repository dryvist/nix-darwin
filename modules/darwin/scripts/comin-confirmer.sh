# shellcheck shell=bash
# Confirm a waiting comin deployment only while the cluster rebuild gate allows activation.
#
# comin's deploy confirmer stays in `manual` mode and this job runs on an interval. When a generation
# waits for deploy confirmation, the job runs the cluster rebuild gate, the same check activation runs
# first:
#   - the gate allows: `comin confirmation accept`, logged with the gate's verdict;
#   - the gate refuses: nothing is confirmed, the refusal is logged, and the generation keeps waiting
#     for the next run.
# A comin that cannot report its state gets nothing confirmed. Every decision is one log line.
#
# Hold: while COMIN_HOLD_FILE holds a valid hold (key=value lines by=, why=, set=, until=, times as
# UTC YYYY-MM-DDTHH:MM:SSZ, until after set and at most 12 hours after set and after now), nothing
# is confirmed and the gate is not run; each run logs one HOLD line. An expired hold logs
# `alert=hold-expired` and the run proceeds as without a hold. An unreadable or malformed hold is
# logged and treated as absent. The file is read as data only, never sourced.
#
# A generation waiting more than 24 hours logs `alert=generation-waiting-24h` on each run; its
# first-seen time is kept in COMIN_WAITING_FILE.
#
# Environment:
#   CLUSTER_REBUILD_GATE_BIN  path to cluster-rebuild-gate (injected by the module; a test seam otherwise)
#   COMIN_HOLD_FILE           hold file path (injected by the module)
#   COMIN_WAITING_FILE        "<generation> <first-seen epoch>" (default under /var/run, cleared at boot)
# `date` must be GNU coreutils date (the module's runtimeInputs): `date -d` parses the hold's times.

gate="${CLUSTER_REBUILD_GATE_BIN:?CLUSTER_REBUILD_GATE_BIN not set}"
hold_file="${COMIN_HOLD_FILE:?COMIN_HOLD_FILE not set}"
waiting_file="${COMIN_WAITING_FILE:-/var/run/comin-confirmer.waiting}"
max_hold=43200
waiting_alert=86400

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
one_line() { tr '\n' ' ' <<< "$1" | sed 's/[[:space:]]*$//'; }
# Hold values are input: control characters stripped, length capped.
clean() { printf '%s' "$1" | tr -d '\000-\037\177' | cut -c1-200; }
log() { echo "$(ts) comin-confirmer: $*"; }

if ! status="$(comin status --json 2>&1)"; then
  log "comin state unreadable; confirming nothing: $(one_line "$status")"
  exit 0
fi

if ! submitted="$(jq -r '.deploy_confirmer.submitted // ""' <<< "$status" 2> /dev/null)"; then
  log "comin state is not JSON; confirming nothing."
  exit 0
fi

now="$(date -u +%s)"

# Sets hold_state to absent, held or expired, and hold_by, hold_why, hold_until.
read_hold() {
  hold_state=absent
  [ -e "$hold_file" ] || return 0
  local text line key value by="" why="" set="" until="" seen=" " set_s until_s
  if [ ! -f "$hold_file" ] || ! text="$(head -c 4096 "$hold_file" 2> /dev/null)"; then
    log "hold file $hold_file ignored (unreadable); treated as absent"
    return 0
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      by | why | set | until) ;;
      *) continue ;;
    esac
    if [[ $seen == *" $key "* ]]; then
      log "hold file $hold_file ignored (duplicate $key); treated as absent"
      return 0
    fi
    seen+="$key "
    printf -v "$key" '%s' "$(clean "$value")"
  done <<< "$text"
  for key in by why set until; do
    if [ -z "${!key}" ]; then
      log "hold file $hold_file ignored (missing $key); treated as absent"
      return 0
    fi
  done
  for key in set until; do
    if [[ ! ${!key} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
      || ! date -u -d "${!key}" +%s > /dev/null 2>&1; then
      log "hold file $hold_file ignored (bad $key time); treated as absent"
      return 0
    fi
  done
  set_s="$(date -u -d "$set" +%s)"
  until_s="$(date -u -d "$until" +%s)"
  if [ "$until_s" -le "$set_s" ]; then
    log "hold file $hold_file ignored (until is not after set); treated as absent"
    return 0
  fi
  if [ $((until_s - set_s)) -gt "$max_hold" ] || [ $((until_s - now)) -gt "$max_hold" ]; then
    log "hold file $hold_file ignored (longer than 12 hours); treated as absent"
    return 0
  fi
  hold_by="$by" hold_why="$why" hold_until="$until"
  if [ "$now" -ge "$until_s" ]; then
    hold_state=expired
  else
    hold_state=held
  fi
}

read_hold
if [ "$hold_state" = expired ]; then
  log "alert=hold-expired hold=$hold_file by=$hold_by until=$hold_until; treated as absent"
fi

# First-seen time of the waiting generation, for the 24-hour alert.
if [ -n "$submitted" ]; then
  first=""
  if read -r seen_gen seen_at 2> /dev/null < "$waiting_file" \
    && [ "$seen_gen" = "$submitted" ] && [[ $seen_at =~ ^[0-9]+$ ]]; then
    first="$seen_at"
  else
    printf '%s %s\n' "$submitted" "$now" > "$waiting_file" 2> /dev/null \
      || log "cannot write $waiting_file; the 24-hour waiting alert is not tracked"
  fi
  if [ -n "$first" ] && [ $((now - first)) -gt "$waiting_alert" ]; then
    log "alert=generation-waiting-24h generation=$submitted since=$(date -u -d "@$first" +%Y-%m-%dT%H:%M:%SZ)"
  fi
else
  rm -f "$waiting_file" 2> /dev/null || true
fi

if [ "$hold_state" = held ]; then
  log "HOLD by=$hold_by why=$hold_why until=$hold_until; confirming nothing, cluster gate not consulted; waiting generation: ${submitted:-none}"
  exit 0
fi

[ -n "$submitted" ] || exit 0

if verdict="$("$gate" 2>&1)"; then
  log "CONFIRMING generation $submitted: $(one_line "$verdict")"
  comin confirmation accept
else
  log "REFUSING generation $submitted until the next check: $(one_line "$verdict")"
fi
