#!/usr/bin/env bats
#
# pf-hardening-trial against a stub pfctl. It must flush com.apple/nix-hardening once the trial
# deadline passes, or at once when that anchor holds rules with no valid deadline, without reading
# the anchor file or resolving a name, and log each time it fires.

load pf_hardening_stubs

setup() {
  pf_stub_setup
  SCRIPT_UNDER_TEST=$(assemble pf-hardening-trial)
  export PF_TRIAL_DEADLINE_FILE="$BATS_TEST_TMPDIR/trial"
  touch "$PF_ENFORCED_RULES"
}

@test "a deadline still ahead does nothing and logs nothing" {
  echo 1800000900 >"$PF_TRIAL_DEADLINE_FILE"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [ ! -s "$PF_CALL_LOG" ]
  [ -f "$PF_ENFORCED_RULES" ]
}

@test "a passed deadline flushes the enforced name, logs it and removes the deadline" {
  echo 1799999999 >"$PF_TRIAL_DEADLINE_FILE"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  grep -Fqx 'pfctl -a com.apple/nix-hardening -F rules' "$PF_CALL_LOG"
  [ ! -f "$PF_ENFORCED_RULES" ]
  [ ! -f "$PF_TRIAL_DEADLINE_FILE" ]
  grep -q 'trial expired: trial deadline 2027-01-15T07:59:59Z passed; flushed com.apple/nix-hardening' "$PF_HARDENING_LOG"
  grep -q '^snapshot info: ' "$PF_HARDENING_LOG"
}

@test "the deadline itself counts as passed" {
  echo 1800000000 >"$PF_TRIAL_DEADLINE_FILE"
  run bash "$SCRIPT_UNDER_TEST"
  [ ! -f "$PF_ENFORCED_RULES" ]
}

@test "rules with no deadline are flushed at once" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [ ! -f "$PF_ENFORCED_RULES" ]
  grep -q 'trial expired: rules present with no trial deadline; flushed com.apple/nix-hardening' "$PF_HARDENING_LOG"
}

@test "a corrupt deadline is flushed at once" {
  for bad in 0100 12abc 99999999999999 ""; do
    touch "$PF_ENFORCED_RULES"
    printf '%s' "$bad" >"$PF_TRIAL_DEADLINE_FILE"
    run bash "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
    [ ! -f "$PF_ENFORCED_RULES" ]
    grep -q 'trial deadline file unreadable; flushed' "$PF_HARDENING_LOG"
  done
}

@test "a directory at the deadline path counts as no deadline" {
  mkdir "$PF_TRIAL_DEADLINE_FILE"
  run bash "$SCRIPT_UNDER_TEST"
  [ ! -f "$PF_ENFORCED_RULES" ]
  grep -q 'rules present with no trial deadline' "$PF_HARDENING_LOG"
}

@test "nothing enforced and no deadline: nothing to do, nothing logged" {
  rm -f "$PF_ENFORCED_RULES"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  run grep -q -e ' -F ' -e '^logger' "$PF_CALL_LOG"
  [ "$status" -eq 1 ]
  [ ! -s "$PF_HARDENING_LOG" ]
}

@test "a passed deadline with nothing enforced still logs once, then stays quiet" {
  rm -f "$PF_ENFORCED_RULES"
  echo 1799999999 >"$PF_TRIAL_DEADLINE_FILE"
  run bash "$SCRIPT_UNDER_TEST"
  grep -q 'trial expired' "$PF_HARDENING_LOG"
  : >"$PF_HARDENING_LOG"
  run bash "$SCRIPT_UNDER_TEST"
  [ ! -s "$PF_HARDENING_LOG" ]
}

@test "a flush that leaves rules fails loudly" {
  PF_FLUSH_STUCK=1 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  grep -q 'FAILED: trial flush: rules present with no trial deadline, but com.apple/nix-hardening still holds rules' "$PF_HARDENING_LOG"
}

@test "flushes without the anchor file, a load or a name lookup" {
  echo 1799999999 >"$PF_TRIAL_DEADLINE_FILE"
  PF_FAIL_LOAD=1 PF_ANCHOR_FILE=/nonexistent run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [ ! -f "$PF_ENFORCED_RULES" ]
  run grep -q -e ' -f ' -e '/etc/pf.anchors' -e '^lsof' "$PF_CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "refuses to run without a deadline path" {
  unset PF_TRIAL_DEADLINE_FILE
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [ ! -s "$PF_CALL_LOG" ]
}
