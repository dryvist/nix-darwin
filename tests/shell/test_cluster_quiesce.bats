#!/usr/bin/env bats
# Guard the properties that keep cluster-quiesce from wedging a rank start.
#
# ponytail: structural assertions over the source, not behavioral ones. Exercising
# the real sweep needs a stubbed /usr/bin/osascript, and that absolute path is
# deliberate (Apple binary, PATH-independent), so it cannot be shadowed via PATH.
# These catch a regression of the 2026-08-07 wedge (name-resolution modal) and the
# 2026-08-22 one (Apple-events consent prompt), which is what they are for.
# Upgrade path if this ever needs to be behavioral: take the osascript path from
# a variable defaulting to /usr/bin/osascript, then point it at a stub here.

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../../hosts/common/scripts/cluster-quiesce.sh"

@test "cluster-quiesce script exists" {
  [ -f "$SCRIPT_UNDER_TEST" ]
}

@test "GUI sweep sends no Apple Events: no tell application of any kind" {
  # Any `tell application ...` sends Apple Events, which need per-executable
  # automation consent — unanswerable under launchd, and re-prompted whenever
  # the responsible executable's path changes. The sweep must stay on the
  # consent-free NSWorkspace/NSRunningApplication path.
  # Comment lines may name the banned construct; code lines may not.
  run bash -c "grep -v '^#' '$SCRIPT_UNDER_TEST' | grep -nE 'tell application'"
  [ "$status" -ne 0 ]

  run grep -q "NSWorkspace's sharedWorkspace" "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  run grep -q "terminate()" "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
}

@test "GUI sweep is bounded on the wall clock and logs the timeout" {
  run grep -qE 'timeout -k [0-9]+ "\$gui_timeout" /usr/bin/osascript' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]

  # 124 = timeout fired; without the branch a bounded sweep still fails silently.
  run grep -q '124' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
}

@test "GUI sweep logs which apps it asked to quit" {
  # A sweep that reclaims nothing must say so — silent no-ops hid a halt once.
  run grep -q 'GUI quit requested for' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
}

@test "a hung GUI sweep does not abort the agent bootout that follows it" {
  # The sweep is best-effort memory reclaim; the bootout is the part that
  # actually frees RAM for the shard, so no sweep failure may exit the script.
  # `exit` only: the AppleScript heredoc's `return` is not a shell exit.
  run grep -nE '^\s*exit ' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  # The idempotence guard's `exit 0` is the only early exit.
  [ "$(echo "$output" | grep -c 'exit 0')" -eq 1 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
}
