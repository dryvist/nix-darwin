# Load the nix-hardening pf rules into PF_ANCHOR and enable pf.
#
# PF_ANCHOR is com.apple/nix-hardening when security.pf.enforce is on (the stock
# /etc/pf.conf evaluates every com.apple/* anchor) and nix-hardening otherwise
# (loaded but never evaluated). PF_OTHER_ANCHOR is the other name; its rules are
# flushed so switching enforcement on or off never leaves a stale copy active.
# A failed load exits non-zero so launchd records it instead of leaving pf unloaded.
# pipefail is what makes a failed pfctl visible through the tee below.
set -euo pipefail
: "${PF_ANCHOR:?}" "${PF_OTHER_ANCHOR:?}" "${PF_ANCHOR_FILE:?}"
PFCTL=${PF_HARDENING_PFCTL:-/sbin/pfctl}
LOGGER=${PF_HARDENING_LOGGER:-/usr/bin/logger}
if ! "$PFCTL" -a "$PF_ANCHOR" -f "$PF_ANCHOR_FILE" 2>&1 | tee >("$LOGGER" -t pf-hardening); then
  "$LOGGER" -t pf-hardening "FAILED to load $PF_ANCHOR_FILE into $PF_ANCHOR - pf anchor NOT active"
  exit 1
fi
"$PFCTL" -a "$PF_OTHER_ANCHOR" -F rules 2>&1 | "$LOGGER" -t pf-hardening || true
"$PFCTL" -e 2>&1 | "$LOGGER" -t pf-hardening || true
"$LOGGER" -t pf-hardening "anchor $PF_ANCHOR loaded and pf enabled"
