# Load the nix-hardening pf rules into PF_ANCHOR and enable pf.
#
# PF_ANCHOR is com.apple/nix-hardening when security.pf.enforce is on (the stock
# /etc/pf.conf evaluates every com.apple/* anchor) and nix-hardening otherwise
# (loaded but never evaluated). PF_OTHER_ANCHOR is the other name; its rules are
# flushed so switching enforcement on or off never leaves a stale copy active.
# Any failure exits non-zero so launchd records it and retries.
# pipefail is what makes a failed pfctl visible through the tee below.
set -euo pipefail
: "${PF_ANCHOR:?}" "${PF_OTHER_ANCHOR:?}" "${PF_ANCHOR_FILE:?}"
PFCTL=${PF_HARDENING_PFCTL:-/sbin/pfctl}
LOGGER=${PF_HARDENING_LOGGER:-/usr/bin/logger}
fail() {
  "$LOGGER" -t pf-hardening "FAILED: $1"
  exit 1
}
# The other anchor is flushed when its rule listing succeeds and is empty. A
# failed listing proves nothing by itself: it counts only when the parent's
# anchor list also omits the name (pf drops an anchor that holds no rules).
flushed() {
  local rules parent anchors anchor
  if rules=$("$PFCTL" -a "$PF_OTHER_ANCHOR" -s rules 2>/dev/null); then
    [ -z "$rules" ]
    return
  fi
  parent=${PF_OTHER_ANCHOR%/*}
  [ "$parent" != "$PF_OTHER_ANCHOR" ] || parent=
  anchors=$("$PFCTL" ${parent:+-a "$parent"} -s Anchors 2>/dev/null) || return 1
  while read -r anchor; do
    [ "$anchor" != "$PF_OTHER_ANCHOR" ] && [ "$anchor" != "${PF_OTHER_ANCHOR##*/}" ] || return 1
  done <<<"$anchors"
}
if ! "$PFCTL" -a "$PF_ANCHOR" -f "$PF_ANCHOR_FILE" 2>&1 | tee >("$LOGGER" -t pf-hardening); then
  fail "load $PF_ANCHOR_FILE into $PF_ANCHOR - pf anchor NOT active"
fi
# The flush and the enable are judged by the state they leave, not by pfctl's
# exit status: `pfctl -e` also fails when pf is already enabled.
"$PFCTL" -a "$PF_OTHER_ANCHOR" -F rules 2>&1 | "$LOGGER" -t pf-hardening || true
flushed || fail "flush $PF_OTHER_ANCHOR - its rules may still be loaded"
"$PFCTL" -e 2>&1 | "$LOGGER" -t pf-hardening || true
info=$("$PFCTL" -s info 2>/dev/null || true)
[[ $info == *"Status: Enabled"* ]] || fail "enable pf - pf is disabled"
"$LOGGER" -t pf-hardening "anchor $PF_ANCHOR loaded and pf enabled"
