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

@test "expiry waits for the shared lock and reads the replacement deadline" {
  echo 1799999999 >"$PF_TRIAL_DEADLINE_FILE"
  lock_file="$PF_TRIAL_DEADLINE_FILE.lock"
  ready="$BATS_TEST_TMPDIR/lock-ready"
  release="$BATS_TEST_TMPDIR/lock-release"
  attempted="$BATS_TEST_TMPDIR/lock-attempted"
  lockf_wrapper="$BATS_TEST_TMPDIR/lockf"
  # A real advisory locker held while the holder command runs: lockf(1) ships
  # with macOS, flock(1) is in the shell-tests closure for Linux. Both sides
  # of the race go through the same binary and file, so exclusion holds.
  if command -v lockf >/dev/null 2>&1; then
    real_lockf=lockf
    hold_flag=-k
  elif command -v flock >/dev/null 2>&1; then
    real_lockf=flock
    hold_flag=""
  else
    fail "neither lockf nor flock is available"
  fi
  mkfifo "$release"
  # flock has no -k: holding the lock for the command is its default.
  cat >"$lockf_wrapper" <<LOCKF
#!$BASH
: >"\$PF_LOCK_ATTEMPTED"
if [ "\$1" = -k ] && [ -z "$hold_flag" ]; then shift; fi
exec "$real_lockf" "\$@"
LOCKF
  chmod +x "$lockf_wrapper"
  export PF_HARDENING_LOCKF="$lockf_wrapper" PF_LOCK_ATTEMPTED="$attempted"

  (
    "$real_lockf" ${hold_flag:+"$hold_flag"} "$lock_file" bash -c '
      : > "$1"
      read -r _ < "$2"
      printf "1800000900\\n" > "$3"
    ' bash "$ready" "$release" "$PF_TRIAL_DEADLINE_FILE"
  ) &
  holder=$!
  attempts=0
  while [ ! -f "$ready" ] && [ "$attempts" -lt 100 ]; do
    sleep 0.01
    attempts=$((attempts + 1))
  done
  [ -f "$ready" ]

  bash "$SCRIPT_UNDER_TEST" >"$BATS_TEST_TMPDIR/expire.out" 2>&1 &
  expiry=$!
  attempts=0
  while [ ! -f "$attempted" ] && [ "$attempts" -lt 100 ]; do
    sleep 0.01
    attempts=$((attempts + 1))
  done
  lock_attempted=false
  [ ! -f "$attempted" ] || lock_attempted=true
  printf 'release\n' >"$release"
  wait "$holder"
  wait "$expiry"
  [ "$lock_attempted" = true ]
  [ -f "$PF_ENFORCED_RULES" ]
  [ "$(cat "$PF_TRIAL_DEADLINE_FILE")" = 1800000900 ]
  run grep -Fqx 'pfctl -a com.apple/nix-hardening -F rules' "$PF_CALL_LOG"
  [ "$status" -eq 1 ]
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
