#!/usr/bin/env bats
#
# The maintenance-window reconciler, driven against a stub API and a stub
# launchctl. The cases that matter are the state transitions (open on becoming
# clustered, refresh while clustered, close on teardown) and the failure
# posture (loud, non-fatal, retried on the next tick, never a wrong verdict).

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

# Stubs get the shebang of the bash actually running the suite. `/usr/bin/env`
# is NOT available in the Nix build sandbox these tests run in, and a stub that
# fails to exec answers "no" to everything, which reads as a real answer.
write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB_DIR"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  : > "$CALLS"

  # Stub launchctl, same contract as the rebuild-gate test.
  write_stub "$STUB_DIR/launchctl" << 'STUB'
case "$LAUNCHCTL_MODE" in
  running) [[ "$2" == */dev.mlx-cluster.rank ]] && echo "  state = running"; exit 0 ;;
  stopped) [[ "$2" == */dev.mlx-cluster.rank ]] && echo "  state = not running"; exit 0 ;;
esac
exit 0
STUB

  # Stub API. Records every method+path it is asked for, answers the four
  # endpoints the reconciler uses, and fails whichever path FAIL_PATH names so
  # the error branches are reachable.
  write_stub "$STUB_DIR/curl" << 'STUB'
method=GET path=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    http*) path="${1#*/api/v1}"; shift ;;
    *) shift ;;
  esac
done
echo "$method $path" >> "$CALLS"
if [ -n "${FAIL_PATH:-}" ] && [[ "$path" == ${FAIL_PATH} ]]; then
  echo "stub: forced failure for $path" >&2
  exit 22
fi
case "$method $path" in
  "POST /login")        echo '{"token":"stub-jwt"}' ;;
  "PUT /projects/54/tasks") echo '{"id":9001,"title":"host.example"}' ;;
  "GET /labels")        echo '[{"id":7,"title":"other"},{"id":14,"title":"maintenance"}]' ;;
  "PUT /tasks/"*"/labels") echo '{}' ;;
  "POST /tasks/"*)      echo '{"id":9001,"done":true}' ;;
  *) echo '{}' ;;
esac
STUB

  write_stub "$STUB_DIR/rank-live" << STUB
exec bash -euo pipefail "$SCRIPTS/mlx-cluster-rank-live.sh"
STUB

  export MLX_CLUSTER_LAUNCHCTL_BIN="$STUB_DIR/launchctl"
  export MLX_CLUSTER_GUI_UID=501
  export MLX_CLUSTER_RANK_LIVE_BIN="$STUB_DIR/rank-live"
  export MLX_CLUSTER_CURL_BIN="$STUB_DIR/curl"
  export MLX_CLUSTER_WINDOW_PROJECT=54
  export MLX_CLUSTER_WINDOW_LABEL=maintenance
  export MLX_CLUSTER_WINDOW_TITLE=host.example
  export MLX_CLUSTER_WINDOW_HOURS=6
  export MLX_CLUSTER_WINDOW_STATE_FILE="$BATS_TEST_TMPDIR/state/window-task"
  export VIKUNJA_API_URL="https://stub.invalid/api/v1"
  export VIKUNJA_PASSWORD="stub-password"
}

reconcile() {
  run bash -euo pipefail "$SCRIPTS/cluster-maintenance-window.sh"
}

state() { cat "$MLX_CLUSTER_WINDOW_STATE_FILE" 2> /dev/null || true; }

@test "the stubs actually execute — a dead stub would fake every answer" {
  run env LAUNCHCTL_MODE=running "$STUB_DIR/launchctl" print gui/501/dev.mlx-cluster.rank
  [ "$status" -eq 0 ]
  [[ "$output" == *"state = running"* ]]
  run "$STUB_DIR/curl" -X POST "https://stub.invalid/api/v1/login"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stub-jwt"* ]]
}

@test "not clustered with no window: no API call at all" {
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
  [ ! -s "$CALLS" ]
}

@test "becoming clustered opens a window, records it, and labels it" {
  LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [ "$(state)" = "9001" ]
  grep -q "PUT /projects/54/tasks" "$CALLS"
  grep -q "PUT /tasks/9001/labels" "$CALLS"
  [[ "$output" == *"opened window task 9001"* ]]
}

@test "staying clustered refreshes the existing window instead of opening another" {
  LAUNCHCTL_MODE=running reconcile
  : > "$CALLS"
  LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [ "$(state)" = "9001" ]
  grep -q "POST /tasks/9001" "$CALLS"
  ! grep -q "PUT /projects/54/tasks" "$CALLS"
  [[ "$output" == *"refreshed window task 9001"* ]]
}

@test "teardown closes the window and forgets it" {
  LAUNCHCTL_MODE=running reconcile
  : > "$CALLS"
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  grep -q "POST /tasks/9001" "$CALLS"
  [ -z "$(state)" ]
  [[ "$output" == *"closed window task 9001"* ]]
}

@test "a failed close keeps the id so the next tick retries" {
  LAUNCHCTL_MODE=running reconcile
  FAIL_PATH='/tasks/9001' LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"could NOT close"* ]]
  [ "$(state)" = "9001" ]
  LAUNCHCTL_MODE=stopped reconcile
  [ -z "$(state)" ]
}

@test "a failed refresh forgets the id rather than refreshing a ghost forever" {
  LAUNCHCTL_MODE=running reconcile
  FAIL_PATH='/tasks/9001' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"forgetting it"* ]]
  [ -z "$(state)" ]
}

@test "an API that will not authenticate is loud, non-fatal, and opens nothing" {
  FAIL_PATH='/login' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"login as svc-mcp-rw failed"* ]]
  [ -z "$(state)" ]
}

@test "an unseeded environment never blocks: no API URL, no password, still exit 0" {
  VIKUNJA_API_URL="" LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"VIKUNJA_API_URL not set"* ]]
  [ ! -s "$CALLS" ]

  VIKUNJA_PASSWORD="" LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"no service-account password"* ]]
}

@test "a label that cannot be resolved leaves the window open and says so" {
  FAIL_PATH='/labels' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [ "$(state)" = "9001" ]
  [[ "$output" == *"could not resolve a label"* ]]
}

@test "each API call is attempted the configured number of times, then deferred" {
  MLX_CLUSTER_WINDOW_ATTEMPTS=3 FAIL_PATH='/login' LAUNCHCTL_MODE=running reconcile
  [ "$(grep -c 'POST /login' "$CALLS")" -eq 3 ]
}

@test "no GUI launchd domain is treated as not clustered, and logged as undetermined" {
  MLX_CLUSTER_GUI_UID=0 LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNDETERMINED"* ]]
  [[ "$output" == *"nothing to do"* ]]
}
