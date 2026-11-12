# End an enforce trial: flush com.apple/nix-hardening once the trial deadline passes.
#
# launchd runs this at load and every 30 s while security.pf.enforceTrialSeconds is set.
# pf-hardening-load arms the deadline before the first enforced load when none is valid, preserves
# it across retries, and renews an expired deadline only after a successful load. Here:
#   - a valid deadline still in the future: nothing to do, nothing logged;
#   - the enforced name holds no rules and no deadline is pending: nothing to do;
#   - otherwise (deadline passed, or rules present with no valid deadline): flush the enforced
#     name, log the decision, remove the deadline and log a snapshot.
# It reads no anchor file, resolves no name and uses no network. It reads the deadline file and
# serializes with loads through lockf on the adjacent .lock file. A reboot clears pf's anchors, so
# the host comes up non-enforcing; the boot load re-arms the full trial before it enforces again.
set -uo pipefail
set +e # flushed() is a test; writeShellApplication turned -e on
: "${PF_TRIAL_DEADLINE_FILE:?}"
lock_trial "$@"

deadline=""
if [ -f "$PF_TRIAL_DEADLINE_FILE" ]; then
  deadline=$(head -c 32 "$PF_TRIAL_DEADLINE_FILE" 2>/dev/null | tr -d '\n')
  [[ $deadline =~ ^[1-9][0-9]{8,11}$ ]] || deadline="corrupt"
fi
t=$(now)

if [[ $deadline =~ ^[0-9]+$ ]] && [ "$t" -lt "$deadline" ]; then
  exit 0
fi
if [ -z "$deadline" ] && flushed "$ENFORCED_ANCHOR"; then
  exit 0
fi

case $deadline in
  "") reason="rules present with no trial deadline" ;;
  corrupt) reason="trial deadline file unreadable" ;;
  *) reason="trial deadline $(iso "$deadline") passed" ;;
esac
"$PFCTL" -a "$ENFORCED_ANCHOR" -F rules >>"$LOG" 2>&1 || true
if ! flushed "$ENFORCED_ANCHOR"; then
  snapshot
  fail "trial flush: $reason, but $ENFORCED_ANCHOR still holds rules"
fi
rm -f "$PF_TRIAL_DEADLINE_FILE"
say "trial expired: $reason; flushed $ENFORCED_ANCHOR"
snapshot
