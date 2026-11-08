#!/usr/bin/env bats

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../../modules/darwin/scripts/pf-hardening-load.sh"

setup() {
  export PF_HARDENING_PFCTL="$BATS_TEST_TMPDIR/pfctl"
  export PF_HARDENING_LOGGER="$BATS_TEST_TMPDIR/logger"
  export PF_CALL_LOG="$BATS_TEST_TMPDIR/calls"
  export PF_ANCHOR=com.apple/nix-hardening
  export PF_OTHER_ANCHOR=nix-hardening
  export PF_ANCHOR_FILE=/etc/pf.anchors/nix-hardening
  : >"$PF_CALL_LOG"
  printf '#!%s\n' "$BASH" >"$PF_HARDENING_PFCTL"
  cat >>"$PF_HARDENING_PFCTL" <<'STUB'
printf 'pfctl %s\n' "$*" >>"$PF_CALL_LOG"
if [ -n "${PF_FAIL_LOAD:-}" ] && [ "${3:-}" = -f ]; then
  echo "syntax error" >&2
  exit 1
fi
STUB
  printf '#!%s\ncat >/dev/null\nprintf "logger %%s\\n" "$*" >>"$PF_CALL_LOG"\n' "$BASH" >"$PF_HARDENING_LOGGER"
  chmod +x "$PF_HARDENING_PFCTL" "$PF_HARDENING_LOGGER"
}

@test "loads the anchor file into PF_ANCHOR, flushes the other name, then enables pf" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  run grep '^pfctl' "$PF_CALL_LOG"
  [ "${lines[0]}" = "pfctl -a com.apple/nix-hardening -f /etc/pf.anchors/nix-hardening" ]
  [ "${lines[1]}" = "pfctl -a nix-hardening -F rules" ]
  [ "${lines[2]}" = "pfctl -e" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "a failed load exits non-zero and keeps the other anchor and pf state untouched" {
  PF_FAIL_LOAD=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  run grep '^pfctl' "$PF_CALL_LOG"
  [ "${#lines[@]}" -eq 1 ]
  grep -q 'FAILED to load /etc/pf.anchors/nix-hardening into com.apple/nix-hardening' "$PF_CALL_LOG"
}

@test "refuses to run without an anchor name" {
  unset PF_ANCHOR
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [ ! -s "$PF_CALL_LOG" ]
}
