# Load the nix-hardening pf rules into PF_ANCHOR and enable pf.
#
# PF_ANCHOR is com.apple/nix-hardening when security.pf.enforce is on (the stock
# /etc/pf.conf evaluates every com.apple/* anchor) and nix-hardening otherwise
# (loaded but never evaluated). PF_OTHER_ANCHOR is the other name; its rules are
# flushed first, before the load, so a failed load (for example a source name that
# does not resolve) never leaves the previous copy active: turning enforcement off
# removes it even when the new rules cannot load.
#
# With PF_TRIAL_SECONDS set (security.pf.enforceTrialSeconds, enforce on), the trial
# deadline is written to PF_TRIAL_DEADLINE_FILE before every enforced load, so no
# enforced load runs without a timer; pf-hardening-trial flushes the enforced name
# once the deadline passes. The first listening-socket snapshot is logged with it.
#
# Every run ends with a snapshot of pf state in the file log (./pf-hardening-lib.sh,
# prepended by the module). Any failure exits non-zero so launchd records it and retries.
# pipefail is what makes a failed pfctl visible through the tee below.
set -euo pipefail
: "${PF_ANCHOR:?}" "${PF_OTHER_ANCHOR:?}" "${PF_ANCHOR_FILE:?}"
if [ -n "${PF_TRIAL_SECONDS:-}" ]; then
  : "${PF_TRIAL_DEADLINE_FILE:?}"
  deadline=$(($(now) + PF_TRIAL_SECONDS))
  tmp=$(mktemp "$PF_TRIAL_DEADLINE_FILE.XXXXXX")
  echo "$deadline" >"$tmp"
  mv -f "$tmp" "$PF_TRIAL_DEADLINE_FILE"
  say "trial armed: $PF_ANCHOR is flushed at $(iso "$deadline") (${PF_TRIAL_SECONDS} s)"
  listeners
fi

# The flush and the enable are judged by the state they leave, not by pfctl's
# exit status: `pfctl -e` also fails when pf is already enabled.
"$PFCTL" -a "$PF_OTHER_ANCHOR" -F rules 2>&1 | tee -a "$LOG" >("$LOGGER" -t pf-hardening) || true
flushed "$PF_OTHER_ANCHOR" || { snapshot; fail "flush $PF_OTHER_ANCHOR - its rules may still be loaded"; }
if ! "$PFCTL" -a "$PF_ANCHOR" -f "$PF_ANCHOR_FILE" 2>&1 | tee -a "$LOG" >("$LOGGER" -t pf-hardening); then
  snapshot
  fail "load $PF_ANCHOR_FILE into $PF_ANCHOR - pf anchor NOT active"
fi
"$PFCTL" -e 2>&1 | tee -a "$LOG" >("$LOGGER" -t pf-hardening) || true
info=$("$PFCTL" -s info 2>/dev/null || true)
[[ $info == *"Status: Enabled"* ]] || { snapshot; fail "enable pf - pf is disabled"; }
say "anchor $PF_ANCHOR loaded and pf enabled"
snapshot
