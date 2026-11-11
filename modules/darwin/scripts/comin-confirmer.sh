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
# Hold: while COMIN_HOLD_FILE holds a valid hold (format and validity in ./comin-hold-lib.sh, which
# the module prepends to this script), nothing is confirmed and the gate is not run; each run logs one
# HOLD line. An expired hold logs `alert=hold-expired` and the run proceeds as without a hold. An
# unreadable or malformed hold is logged and treated as absent.
#
# A generation waiting more than 24 hours logs `alert=generation-waiting-24h` on each run; its
# first-seen time is kept in COMIN_WAITING_FILE, read only when it is a regular file holding a
# plausible epoch; anything else is logged and restarts the clock. A `comin status` that fails logs
# `alert=comin-control-unreachable` on each run.
#
# Environment:
#   CLUSTER_REBUILD_GATE_BIN  path to cluster-rebuild-gate (injected by the module; a test seam otherwise)
#   COMIN_HOLD_FILE           hold file path (injected by the module)
#   COMIN_WAITING_FILE        "<generation> <first-seen epoch>" (default under /var/run, cleared at boot)
# `date` must be GNU coreutils date (the module's runtimeInputs): `date -d` parses the hold's times.

gate="${CLUSTER_REBUILD_GATE_BIN:?CLUSTER_REBUILD_GATE_BIN not set}"
hold_file="${COMIN_HOLD_FILE:?COMIN_HOLD_FILE not set}"
waiting_file="${COMIN_WAITING_FILE:-/var/run/comin-confirmer.waiting}"
waiting_alert=86400

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
one_line() { tr '\n' ' ' <<< "$1" | sed 's/[[:space:]]*$//'; }
log() { echo "$(ts) comin-confirmer: $*"; }

# comin's control server is down or refusing: a fault to alert on, not a wait.
if ! status="$(comin status --json 2>&1)"; then
  log "alert=comin-control-unreachable comin state unreadable; confirming nothing: $(one_line "$status" | cut -c1-200)"
  exit 0
fi

if ! submitted="$(jq -r '.deploy_confirmer.submitted // ""' <<< "$status" 2> /dev/null)"; then
  log "comin state is not JSON; confirming nothing."
  exit 0
fi

now="$(date -u +%s)"

read_hold
case "$hold_state" in
  unreadable) log "hold file $hold_file ignored (unreadable); treated as absent" ;;
  malformed) log "hold file $hold_file ignored ($hold_reason); treated as absent" ;;
  expired) log "alert=hold-expired hold=$hold_file by=$hold_by until=$hold_until; treated as absent" ;;
esac

# First-seen time of the waiting generation, for the 24-hour alert. The file is read only when it is
# a regular file, at most 256 bytes; the epoch must be 9 to 12 plain decimal digits, no leading zero,
# not in the future. It is replaced by rename, so a FIFO or other file there never blocks the run.
record_waiting() {
  local tmp
  if tmp="$(mktemp "$waiting_file.XXXXXX" 2> /dev/null)" \
    && printf '%s %s\n' "$submitted" "$now" > "$tmp" && mv -f "$tmp" "$waiting_file"; then
    return 0
  fi
  rm -f "$tmp" 2> /dev/null || true
  log "cannot write $waiting_file; the 24-hour waiting alert is not tracked"
}
if [ -n "$submitted" ]; then
  first="" seen_gen="" seen_at=""
  if [ -f "$waiting_file" ]; then
    read -r seen_gen seen_at < <(head -c 256 "$waiting_file" 2> /dev/null) || true
  fi
  if [ "$seen_gen" = "$submitted" ] && [[ $seen_at =~ ^[1-9][0-9]{8,11}$ ]] && [ "$seen_at" -le "$now" ]; then
    first="$seen_at"
  else
    if [ -e "$waiting_file" ] && [ "$seen_gen" = "$submitted" ]; then
      log "waiting state $waiting_file unreadable or corrupt; generation $submitted first seen now"
    elif [ -e "$waiting_file" ] && [ ! -f "$waiting_file" ]; then
      log "waiting state $waiting_file is not a regular file; generation $submitted first seen now"
    fi
    record_waiting
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
