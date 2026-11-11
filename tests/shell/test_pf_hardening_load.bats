#!/usr/bin/env bats

load pf_hardening_stubs

setup() {
  pf_stub_setup
  SCRIPT_UNDER_TEST=$(assemble pf-hardening-load)
  export PF_ANCHOR=com.apple/nix-hardening
  export PF_OTHER_ANCHOR=nix-hardening
  export PF_ANCHOR_FILE=/etc/pf.anchors/nix-hardening
}

@test "flushes the other name, then loads PF_ANCHOR, enables pf and checks both results" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  run grep '^pfctl' "$PF_CALL_LOG"
  [ "${lines[0]}" = "pfctl -a nix-hardening -F rules" ]
  [ "${lines[1]}" = "pfctl -a nix-hardening -s rules" ]
  [ "${lines[2]}" = "pfctl -a com.apple/nix-hardening -f /etc/pf.anchors/nix-hardening" ]
  [ "${lines[3]}" = "pfctl -e" ]
  [ "${lines[4]}" = "pfctl -s info" ]
  # Everything after is the snapshot: reads only.
  run grep -c -e ' -F ' -e ' -f ' -e '^pfctl -e' "$PF_CALL_LOG"
  [ "$output" -eq 3 ]
}

@test "enforce on: a failed load exits non-zero with the inert name already flushed" {
  PF_FAIL_LOAD=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  run grep '^pfctl' "$PF_CALL_LOG"
  [ "${lines[0]}" = "pfctl -a nix-hardening -F rules" ]
  [ "${lines[1]}" = "pfctl -a nix-hardening -s rules" ]
  [ "${lines[2]}" = "pfctl -a com.apple/nix-hardening -f /etc/pf.anchors/nix-hardening" ]
  run grep -q '^pfctl -e' "$PF_CALL_LOG"
  [ "$status" -eq 1 ]
  grep -q 'FAILED: load /etc/pf.anchors/nix-hardening into com.apple/nix-hardening' "$PF_CALL_LOG"
}

@test "enforce off: a failed load still flushes the enforced name first" {
  PF_ANCHOR=nix-hardening PF_OTHER_ANCHOR=com.apple/nix-hardening PF_FAIL_LOAD=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  run grep '^pfctl' "$PF_CALL_LOG"
  [ "${lines[0]}" = "pfctl -a com.apple/nix-hardening -F rules" ]
  [ "${lines[1]}" = "pfctl -a com.apple/nix-hardening -s rules" ]
  [ "${lines[2]}" = "pfctl -a nix-hardening -f /etc/pf.anchors/nix-hardening" ]
  grep -q 'FAILED: load /etc/pf.anchors/nix-hardening into nix-hardening' "$PF_CALL_LOG"
}

@test "rules left in the other anchor after the flush fail the run before the load" {
  PF_STALE_RULES=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  grep -q 'FAILED: flush nix-hardening' "$PF_CALL_LOG"
  # A bare `! cmd` never fails a bats test, so the absence checks use `run`.
  run grep -q -e ' -f ' -e '^pfctl -e' "$PF_CALL_LOG"
  [ "$status" -eq 1 ]
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
  run grep -q '^pfctl -e' "$PF_CALL_LOG"
  [ "$status" -eq 1 ]
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

@test "decision lines go to the file log as well as the unified log" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  grep -q 'pf-hardening: anchor com.apple/nix-hardening loaded and pf enabled$' "$PF_HARDENING_LOG"
  grep -q 'logger -t pf-hardening anchor com.apple/nix-hardening loaded and pf enabled' "$PF_CALL_LOG"
  PF_FAIL_LOAD=1 run bash "$SCRIPT_UNDER_TEST"
  grep -q 'pf-hardening: FAILED: load ' "$PF_HARDENING_LOG"
  grep -q 'no IP address found for example.invalid' "$PF_HARDENING_LOG"
}

@test "every load ends with a snapshot of pf state in the file log" {
  run bash "$SCRIPT_UNDER_TEST"
  grep -q '^snapshot info: Status: Enabled' "$PF_HARDENING_LOG"
  grep -q '^snapshot info:   current entries' "$PF_HARDENING_LOG"
  grep -Fqx 'pfctl -a com.apple/nix-hardening -s rules' "$PF_CALL_LOG"
  grep -Fqx 'pfctl -a nix-hardening -s rules' "$PF_CALL_LOG"
  grep -q '^snapshot anchors: ' "$PF_HARDENING_LOG"
  grep -q '^snapshot anchors com.apple: ' "$PF_HARDENING_LOG"
  : >"$PF_HARDENING_LOG"
  PF_FAIL_LOAD=1 run bash "$SCRIPT_UNDER_TEST"
  grep -q '^snapshot info: ' "$PF_HARDENING_LOG"
}

@test "each snapshot section is bounded" {
  PF_MANY_RULES=1 run bash "$SCRIPT_UNDER_TEST"
  run grep -c '^snapshot rules nix-hardening: ' "$PF_HARDENING_LOG"
  [ "$output" -eq 200 ]
}

@test "without a trial nothing is armed and no listeners are logged" {
  run bash "$SCRIPT_UNDER_TEST"
  run grep -q -e '^lsof' -e 'trial armed' "$PF_CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "trial: the deadline is written before the enforced load, then listeners are logged" {
  export PF_TRIAL_SECONDS=900 PF_TRIAL_DEADLINE_FILE="$BATS_TEST_TMPDIR/trial"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [ "$(cat "$PF_TRIAL_DEADLINE_FILE")" = 1800000900 ]
  grep -Fqx 'probe deadline-at-load 1800000900' "$PF_CALL_LOG"
  grep -q 'trial armed: com.apple/nix-hardening is flushed at 2027-01-15T08:15:00Z (900 s)' "$PF_HARDENING_LOG"
  grep -q '^snapshot listen tcp: sshd' "$PF_HARDENING_LOG"
}

@test "trial: a failed load is still armed and logged" {
  export PF_TRIAL_SECONDS=900 PF_TRIAL_DEADLINE_FILE="$BATS_TEST_TMPDIR/trial"
  PF_FAIL_LOAD=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  grep -q 'trial armed' "$PF_HARDENING_LOG"
  grep -q 'FAILED: load' "$PF_HARDENING_LOG"
}

@test "trial: after a reboot the boot load re-arms the full time before enforcing" {
  export PF_TRIAL_SECONDS=900 PF_TRIAL_DEADLINE_FILE="$BATS_TEST_TMPDIR/trial"
  echo 1799999000 >"$PF_TRIAL_DEADLINE_FILE" # left from before the reboot, already passed
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  grep -Fqx 'probe deadline-at-load 1800000900' "$PF_CALL_LOG"
}
