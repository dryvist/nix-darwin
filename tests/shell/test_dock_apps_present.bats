#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../../modules/darwin/scripts/dock-apps-present.sh"

setup() {
  APP_DIR="$BATS_TEST_TMPDIR/apps"
  mkdir -p "$APP_DIR/Slack.app" "$APP_DIR/Visual Studio Code.app" "$BATS_TEST_TMPDIR/Home Manager Apps"
}

@test "all existing paths are reported as present" {
  run --separate-stderr bash "$SCRIPT" \
    "$APP_DIR/Slack.app" \
    "$APP_DIR/Visual Studio Code.app" \
    "$BATS_TEST_TMPDIR/Home Manager Apps"

  [ "$status" -eq 0 ]
  [[ "$stderr" != *"[ERROR]"* ]]
  [[ "$output" == *"present: 3/3"* ]]
}

@test "a missing path is reported while existing paths count as present" {
  missing="$APP_DIR/Missing App.app"
  run --separate-stderr bash "$SCRIPT" \
    "$APP_DIR/Slack.app" \
    "$missing" \
    "$BATS_TEST_TMPDIR/Home Manager Apps"

  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$stderr" | grep -c '\[ERROR\]')" -eq 1 ]
  [[ "$stderr" == *"[ERROR] dock app missing: $missing"* ]]
  [[ "$output" == *"present: 2/3"* ]]
}

@test "all missing paths produce three errors and exit successfully" {
  run --separate-stderr bash "$SCRIPT" \
    "$APP_DIR/Missing One.app" \
    "$APP_DIR/Missing Two.app" \
    "$APP_DIR/Missing Three.app"

  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$stderr" | grep -c '\[ERROR\]')" -eq 3 ]
  [[ "$output" == *"present: 0/3"* ]]
}

@test "zero arguments are valid" {
  run --separate-stderr bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [[ "$output" == *"present: 0/0"* ]]
}
