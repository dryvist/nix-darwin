#!/usr/bin/env bats

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../../modules/darwin/scripts/system-limits.sh"

setup() {
  export SYSTEM_LIMITS_APPLY_SYSCTLS=0
  export LAUNCHCTL_MAXFILES_SOFT=65536
  export LAUNCHCTL_MAXFILES_HARD=65536
  export SYSTEM_LIMITS_LAUNCHCTL="$BATS_TEST_TMPDIR/launchctl"
  export SYSTEM_LIMITS_STAT="$BATS_TEST_TMPDIR/stat"
  export SYSTEM_LIMITS_CALL_LOG="$BATS_TEST_TMPDIR/calls"
  : >"$SYSTEM_LIMITS_CALL_LOG"

  cat >"$SYSTEM_LIMITS_LAUNCHCTL" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SYSTEM_LIMITS_CALL_LOG"
if [ "${1:-}" = asuser ] && [ "${FAIL_GUI_LIMIT:-0}" = 1 ]; then
  exit 1
fi
STUB
  chmod +x "$SYSTEM_LIMITS_LAUNCHCTL"

  cat >"$SYSTEM_LIMITS_STAT" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${SYSTEM_LIMITS_TEST_CONSOLE_UID:?}"
STUB
  chmod +x "$SYSTEM_LIMITS_STAT"
}

@test "sets maxfiles in the current and active GUI launchd contexts" {
  export SYSTEM_LIMITS_TEST_CONSOLE_UID=501

  run bash "$SCRIPT_UNDER_TEST"

  [ "$status" -eq 0 ]
  grep -Fqx -- "limit maxfiles 65536 65536" "$SYSTEM_LIMITS_CALL_LOG"
  grep -Fqx -- "asuser 501 $SYSTEM_LIMITS_LAUNCHCTL limit maxfiles 65536 65536" "$SYSTEM_LIMITS_CALL_LOG"
  [[ "$output" == *"launchctl asuser 501 limit maxfiles 65536 65536"* ]]
}

@test "defers GUI limit until login when loginwindow owns the console" {
  export SYSTEM_LIMITS_TEST_CONSOLE_UID=0

  run bash "$SCRIPT_UNDER_TEST"

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$SYSTEM_LIMITS_CALL_LOG")" -eq 1 ]
  [[ "$output" == *"no GUI console user; GUI maxfiles limit deferred until login"* ]]
}

@test "reports failure to set the active GUI limit" {
  export SYSTEM_LIMITS_TEST_CONSOLE_UID=501
  export FAIL_GUI_LIMIT=1

  run bash "$SCRIPT_UNDER_TEST"

  [ "$status" -eq 1 ]
  [[ "$output" == *"GUI launchctl limit maxfiles failed for console uid 501"* ]]
}
