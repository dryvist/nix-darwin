#!/usr/bin/env bats
#
# The scheduled command uses the real rebuild gate against fixture state, plus
# executable stubs for platform and endpoint boundaries.

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"
JOB_SCRIPT="$SCRIPTS/mac-schedule.sh"
GATE_SCRIPT="$SCRIPTS/cluster-rebuild-gate.sh"

write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB_DIR"

  export DECISION_LOG="$BATS_TEST_TMPDIR/decisions"
  export CURL_ARGS="$BATS_TEST_TMPDIR/curl-args"
  export JQ_ARGS="$BATS_TEST_TMPDIR/jq-args"
  export WORKLOAD_ARGS="$BATS_TEST_TMPDIR/workload-args"
  export CLUSTER_GATE_SCRIPT="$GATE_SCRIPT"
  export CLUSTER_USER_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$CLUSTER_USER_HOME"

  export MAC_SCHEDULE_GATE_BIN="$STUB_DIR/gate"
  export MAC_SCHEDULE_LOGGER_BIN="$STUB_DIR/logger"
  export MAC_SCHEDULE_PMSET_BIN="$STUB_DIR/pmset"
  export MAC_SCHEDULE_CURL_BIN="$STUB_DIR/curl"
  export MAC_SCHEDULE_JQ_BIN="$STUB_DIR/jq"
  export MAC_SCHEDULE_MODEL_ENDPOINT="file:///fixture"
  export MAC_SCHEDULE_MODEL_ID="fixture-model"

  export MLX_CLUSTER_RANK_LIVE_BIN="$STUB_DIR/rank-live"
  write_stub "$STUB_DIR/rank-live" <<'STUB'
exit "${RANK_LIVE_STATUS:-1}"
STUB

  write_stub "$STUB_DIR/gate" <<'STUB'
exec bash -euo pipefail "$CLUSTER_GATE_SCRIPT"
STUB

  write_stub "$STUB_DIR/logger" <<'STUB'
[ "$1" = "-t" ] && [ "$2" = "mac-schedule" ]
printf '%s\n' "$3" >> "$DECISION_LOG"
STUB

  write_stub "$STUB_DIR/pmset" <<'STUB'
printf '%s\n' "$PMSET_OUTPUT"
exit "${PMSET_STATUS:-0}"
STUB

  write_stub "$STUB_DIR/curl" <<'STUB'
printf '%s\n' "$*" >> "$CURL_ARGS"
case "$CURL_MODE" in
  matching) printf '%s\n' '{"data":[{"id":"fixture-model"}]}' ;;
  missing) printf '%s\n' '{"data":[{"id":"other-model"}]}' ;;
  failure) exit 22 ;;
  *) exit 1 ;;
esac
STUB

  write_stub "$STUB_DIR/jq" <<'STUB'
cat >/dev/null
printf '%s\n' "$*" >> "$JQ_ARGS"
case "$JQ_MODE" in
  matching) exit 0 ;;
  missing) exit 1 ;;
  *) exit 2 ;;
esac
STUB
}

cluster_state() {
  local dir="$CLUSTER_USER_HOME/Library/Application Support/mlx-cluster"
  mkdir -p "$dir"
  printf '%s\n' "$1" > "$dir/link-state"
  if [ "$#" -ge 2 ]; then
    printf '%s\n' "$2" > "$dir/peer-state.json"
  fi
}

schedule() {
  run bash -euo pipefail "$JOB_SCRIPT" "$@"
}

assert_decision() {
  [ "$(wc -l < "$DECISION_LOG" | tr -d ' ')" -eq 1 ]
  [ "$(cat "$DECISION_LOG")" = "decision=$1" ]
}

@test "cluster link and armed peer skip the scheduled command" {
  cluster_state up '{"armed": true}'
  schedule /usr/bin/true
  [ "$status" -eq 0 ]
  assert_decision skip-clustered
  [ ! -e "$CURL_ARGS" ]
}

@test "unreadable peer state while the link is up skips as clustered" {
  cluster_state up
  schedule /usr/bin/true
  [ "$status" -eq 0 ]
  assert_decision skip-clustered
  [ ! -e "$CURL_ARGS" ]
}

@test "gate exit 3 stops with a nonzero result" {
  write_stub "$STUB_DIR/gate" <<'STUB'
exit 3
STUB
  schedule /usr/bin/true
  [ "$status" -eq 3 ]
  assert_decision stop-gate-3
  [ ! -e "$CURL_ARGS" ]
}

@test "unexpected gate status stops with its status" {
  write_stub "$STUB_DIR/gate" <<'STUB'
exit 2
STUB
  schedule /usr/bin/true
  [ "$status" -eq 2 ]
  assert_decision stop-gate-2
}

@test "non-AC power skips the model check and command" {
  cluster_state down '{"armed": false}'
  export PMSET_OUTPUT="Now drawing from 'Battery Power'"
  schedule /usr/bin/true
  [ "$status" -eq 0 ]
  assert_decision skip-battery
  [ ! -e "$CURL_ARGS" ]
}

@test "pmset failure is treated as not proven to be on AC" {
  cluster_state down '{"armed": false}'
  export PMSET_STATUS=1
  schedule /usr/bin/true
  [ "$status" -eq 0 ]
  assert_decision skip-battery
}

@test "missing model skips the configured command" {
  cluster_state down '{"armed": false}'
  export PMSET_OUTPUT="Now drawing from 'AC Power'"
  export CURL_MODE=missing
  export JQ_MODE=missing
  schedule /usr/bin/true
  [ "$status" -eq 0 ]
  assert_decision skip-model-missing
  [[ "$(cat "$CURL_ARGS")" == *"file:///fixture/v1/models"* ]]
  [[ "$(cat "$JQ_ARGS")" == *"fixture-model"* ]]
}

@test "unreachable model endpoint skips the configured command" {
  cluster_state down '{"armed": false}'
  export PMSET_OUTPUT="Now drawing from 'AC Power'"
  export CURL_MODE=failure
  schedule /usr/bin/true
  [ "$status" -eq 0 ]
  assert_decision skip-model-missing
}

@test "present model permits the configured command" {
  cluster_state down '{"armed": false}'
  export PMSET_OUTPUT="Now drawing from 'AC Power'"
  export CURL_MODE=matching
  export JQ_MODE=matching
  write_stub "$STUB_DIR/workload" <<'STUB'
printf '%s\n' "$@" > "$WORKLOAD_ARGS"
STUB
  schedule "$STUB_DIR/workload" first second
  [ "$status" -eq 0 ]
  assert_decision run-command
  [ "$(cat "$WORKLOAD_ARGS")" = $'first\nsecond' ]
}
