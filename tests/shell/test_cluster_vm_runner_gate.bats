#!/usr/bin/env bats
#
# The VM-runner gate starts the runner only on a positive "not clustered" and
# stops it on every other answer. Exercised against stub launchctl and
# rank-live, asserting the launchctl action taken and the logged decision.

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  STATE_DIR="$BATS_TEST_TMPDIR/state"
  mkdir -p "$STUB_DIR" "$STATE_DIR"
  ACTIONS="$BATS_TEST_TMPDIR/actions"
  : > "$ACTIONS"

  # print succeeds when RUNNER_LOADED=1; every other verb is recorded.
  write_stub "$STUB_DIR/launchctl" << STUB
case "\$1" in
  print) [ "\${RUNNER_LOADED:-0}" = 1 ] ;;
  *) echo "\$1" >> "$ACTIONS" ;;
esac
STUB
  write_stub "$STUB_DIR/rank-live" << 'STUB'
exit "${RANK_RC:-1}"
STUB

  export VM_RUNNER_LAUNCHCTL_BIN="$STUB_DIR/launchctl"
  export MLX_CLUSTER_RANK_LIVE_BIN="$STUB_DIR/rank-live"
  export MLX_CLUSTER_STATE_DIR="$STATE_DIR"
  export VM_RUNNER_LABEL=com.nix-darwin.macos-vm-runner
  export VM_RUNNER_PLIST="$BATS_TEST_TMPDIR/runner.plist"
  touch "$VM_RUNNER_PLIST"

  echo down > "$STATE_DIR/link-state"
  echo '{"armed": false}' > "$STATE_DIR/peer-state.json"
}

gate() {
  run bash -euo pipefail "$SCRIPTS/cluster-vm-runner-gate.sh"
}

@test "idle cluster and runner not loaded: starts the runner" {
  RANK_RC=1 RUNNER_LOADED=0 gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"not clustered; started"* ]]
  [ "$(cat "$ACTIONS")" = bootstrap ]
}

@test "live rank: stops a loaded runner" {
  RANK_RC=0 RUNNER_LOADED=1 gate
  [[ "$output" == *"cluster rank is live; stopped"* ]]
  [ "$(cat "$ACTIONS")" = bootout ]
}

@test "undetermined rank state (no console session): stops, never starts" {
  RANK_RC=2 RUNNER_LOADED=1 gate
  [[ "$output" == *"undetermined (rc=2); stopped"* ]]
  [ "$(cat "$ACTIONS")" = bootout ]

  : > "$ACTIONS"
  RANK_RC=2 RUNNER_LOADED=0 gate
  [[ "$output" == *"undetermined (rc=2); "*"is not loaded"* ]]
  [ ! -s "$ACTIONS" ]
}

@test "armed cluster before the rank starts: stops the runner" {
  echo '{"armed": true}' > "$STATE_DIR/peer-state.json"
  RANK_RC=1 RUNNER_LOADED=1 gate
  [[ "$output" == *"cluster armed is 'true'; stopped"* ]]
  [ "$(cat "$ACTIONS")" = bootout ]
}

@test "link up: stops the runner" {
  echo up > "$STATE_DIR/link-state"
  RANK_RC=1 RUNNER_LOADED=1 gate
  [[ "$output" == *"cluster link-state is 'up'; stopped"* ]]
}

@test "missing state files: fail closed, never start" {
  rm "$STATE_DIR/link-state"
  RANK_RC=1 RUNNER_LOADED=0 gate
  [[ "$output" == *"link-state unreadable"* ]]
  [ ! -s "$ACTIONS" ]

  echo down > "$STATE_DIR/link-state"
  rm "$STATE_DIR/peer-state.json"
  RANK_RC=1 RUNNER_LOADED=0 gate
  [[ "$output" == *"peer-state unreadable"* ]]
  [ ! -s "$ACTIONS" ]
}

@test "idle cluster and runner already loaded: no action" {
  RANK_RC=1 RUNNER_LOADED=1 gate
  [[ "$output" == *"already loaded"* ]]
  [ ! -s "$ACTIONS" ]
}
