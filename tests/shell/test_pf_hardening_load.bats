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
case "$*" in
  *" -f "*) [ -z "${PF_FAIL_LOAD:-}" ] || { echo "syntax error" >&2; exit 1; } ;;
  *"-s rules")
    [ -z "${PF_RULES_QUERY_FAILS:-}" ] || { echo "DIOCGETRULES: Invalid argument" >&2; exit 1; }
    [ -z "${PF_STALE_RULES:-}" ] || echo "block drop in all" ;;
  *"-s Anchors")
    [ -z "${PF_ANCHORS_FAIL:-}" ] || exit 1
    printf '  %s\n' ${PF_LISTED_ANCHORS:-com.apple} ;;
  "-e") echo "pf already enabled" >&2; exit 1 ;;
  "-s info") [ -n "${PF_DISABLED:-}" ] && echo "Status: Disabled" || echo "Status: Enabled for 0 days 00:01:00" ;;
esac
STUB
  printf '#!%s\ncat >/dev/null\nprintf "logger %%s\\n" "$*" >>"$PF_CALL_LOG"\n' "$BASH" >"$PF_HARDENING_LOGGER"
  chmod +x "$PF_HARDENING_PFCTL" "$PF_HARDENING_LOGGER"
}

@test "loads PF_ANCHOR, flushes the other name, enables pf and checks both results" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  run grep '^pfctl' "$PF_CALL_LOG"
  [ "${lines[0]}" = "pfctl -a com.apple/nix-hardening -f /etc/pf.anchors/nix-hardening" ]
  [ "${lines[1]}" = "pfctl -a nix-hardening -F rules" ]
  [ "${lines[2]}" = "pfctl -a nix-hardening -s rules" ]
  [ "${lines[3]}" = "pfctl -e" ]
  [ "${lines[4]}" = "pfctl -s info" ]
  [ "${#lines[@]}" -eq 5 ]
}

@test "a failed load exits non-zero and leaves the other anchor and pf state untouched" {
  PF_FAIL_LOAD=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  run grep '^pfctl' "$PF_CALL_LOG"
  [ "${#lines[@]}" -eq 1 ]
  grep -q 'FAILED: load /etc/pf.anchors/nix-hardening into com.apple/nix-hardening' "$PF_CALL_LOG"
}

@test "rules left in the other anchor after the flush fail the run before pf is touched" {
  PF_STALE_RULES=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  grep -q 'FAILED: flush nix-hardening' "$PF_CALL_LOG"
  ! grep -q '^pfctl -e' "$PF_CALL_LOG"
}

@test "a failed rule listing counts as flushed only when the anchor list omits the name" {
  PF_RULES_QUERY_FAILS=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  grep -Fqx 'pfctl -s Anchors' "$PF_CALL_LOG"
}

@test "a failed rule listing with the anchor still listed fails the run" {
  PF_RULES_QUERY_FAILS=1 PF_LISTED_ANCHORS="com.apple nix-hardening" run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  grep -q 'FAILED: flush nix-hardening' "$PF_CALL_LOG"
}

@test "a failed rule listing and a failed anchor list fail the run" {
  PF_RULES_QUERY_FAILS=1 PF_ANCHORS_FAIL=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  ! grep -q '^pfctl -e' "$PF_CALL_LOG"
}

@test "a nested other anchor is looked up in its parent's anchor list" {
  PF_ANCHOR=nix-hardening PF_OTHER_ANCHOR=com.apple/nix-hardening PF_RULES_QUERY_FAILS=1 \
    PF_LISTED_ANCHORS="com.apple/200.AirDrop com.apple/nix-hardening" run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  grep -Fqx 'pfctl -a com.apple -s Anchors' "$PF_CALL_LOG"
}

@test "pf still disabled after the enable fails the run" {
  PF_DISABLED=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  grep -q 'FAILED: enable pf' "$PF_CALL_LOG"
}

@test "refuses to run without an anchor name" {
  unset PF_ANCHOR
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [ ! -s "$PF_CALL_LOG" ]
}
