#!/usr/bin/env bats
# Guard the two properties that keep cluster-quiesce from wedging a rank start.
#
# ponytail: structural assertions over the source, not behavioral ones. Exercising
# the real sweep needs a stubbed /usr/bin/osascript, and that absolute path is
# deliberate (Apple binary, PATH-independent), so it cannot be shadowed via PATH.
# These catch a regression of the 2026-08-07 wedge, which is what they are for.
# Upgrade path if this ever needs to be behavioral: take the osascript path from
# a variable defaulting to /usr/bin/osascript, then point it at a stub here.

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../../hosts/common/scripts/cluster-quiesce.sh"

@test "cluster-quiesce script exists" {
  [ -f "$SCRIPT_UNDER_TEST" ]
}

@test "GUI sweep quits by bundle id, never by app name" {
  # `tell application <name>` opens AppleScript's "Where is...?" chooser when a
  # process name matches no bundle — an unanswerable modal under launchd.
  run grep -nE '^\s*tell application [^i"]' "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]

  run grep -q 'tell application id' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
}

@test "GUI sweep is bounded on the wall clock and logs the timeout" {
  run grep -qE 'timeout -k [0-9]+ "\$gui_timeout" /usr/bin/osascript' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]

  # 124 = timeout fired; without the branch a bounded sweep still fails silently.
  run grep -q '124' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
}

@test "a hung GUI sweep does not abort the agent bootout that follows it" {
  # The sweep is best-effort memory reclaim; the bootout is the part that
  # actually frees RAM for the shard, so no sweep failure may exit the script.
  run grep -nE '^\s*(exit|return) ' "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  # The idempotence guard's `exit 0` is the only early exit.
  [ "$(echo "$output" | grep -c 'exit 0')" -eq 1 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
}
