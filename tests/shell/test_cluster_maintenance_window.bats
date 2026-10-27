#!/usr/bin/env bats
#
# The maintenance-window reconciler, driven against a stub API and a stub
# launchctl. The cases that matter are the state transitions (open on becoming
# clustered, refresh while clustered, close on teardown), the clustered rules
# (rank live, or link up and armed, read as the rebuild gate reads them), and the
# failure posture (loud, non-fatal, retried on the next tick, never a wrong
# verdict, and never a task posted without the fields it already had).

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
  export BODIES="$BATS_TEST_TMPDIR/bodies"
  : > "$CALLS"
  : > "$BODIES"

  # Stub launchctl, same contract as the rebuild-gate test.
  write_stub "$STUB_DIR/launchctl" << 'STUB'
case "$LAUNCHCTL_MODE" in
  running) [[ "$2" == */dev.mlx-cluster.rank ]] && echo "  state = running"; exit 0 ;;
  stopped) [[ "$2" == */dev.mlx-cluster.rank ]] && echo "  state = not running"; exit 0 ;;
esac
exit 0
STUB

  # Stub API. Records every method and path it is asked for, and every body it
  # is sent, then answers the endpoints the reconciler uses. FAIL_PATH fails
  # whichever path it names, so the error branches are reachable. TASK_JSON
  # replaces the task a GET returns, so a malformed task is reachable too.
  write_stub "$STUB_DIR/curl" << 'STUB'
method=GET path="" body="" wcode=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    --data-binary) body="$(cat)"; shift 2 ;;
    -w) wcode=1; shift 2 ;;
    http*) path="${1#*/api/v1}"; shift ;;
    *) shift ;;
  esac
done
echo "$method $path" >> "$CALLS"
# The existence probe (-w '%{http_code}', no -f): answer HTTP_CODE, default 200.
[ -n "$wcode" ] && { printf '%s' "${HTTP_CODE:-200}"; exit 0; }
[ -n "$body" ] && echo "$method $path $body" >> "$BODIES"
if [ -n "${FAIL_PATH:-}" ] && [[ "$path" == $FAIL_PATH ]]; then
  echo "stub: forced failure for $path" >&2
  exit 22
fi
task='{"id":9001,"title":"host.example","description":"keep this description","done":false,"due_date":"2000-01-01T00:00:00Z","labels":[]}'
case "$method $path" in
  "PUT /projects/54/tasks") echo '{"id":9001,"title":"host.example"}' ;;
  "GET /labels") echo '[{"id":7,"title":"other"},{"id":14,"title":"maintenance"}]' ;;
  "PUT /tasks/"*"/labels") echo '{}' ;;
  "GET /tasks/9001") echo "${TASK_JSON:-$task}" ;;
  "POST /tasks/"*) echo '{"id":9001}' ;;
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
  export CLUSTER_USER_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$CLUSTER_USER_HOME/Library/Application Support/mlx-cluster"
  export VIKUNJA_API_URL="https://stub.invalid/api/v1"
  export VIKUNJA_API_TOKEN="stub-token"
}

reconcile() {
  run bash -euo pipefail "$SCRIPTS/cluster-maintenance-window.sh"
}

state() { cat "$MLX_CLUSTER_WINDOW_STATE_FILE" 2> /dev/null || true; }
set_link() { echo "$1" > "$CLUSTER_USER_HOME/Library/Application Support/mlx-cluster/link-state"; }
set_peer() { echo "$1" > "$CLUSTER_USER_HOME/Library/Application Support/mlx-cluster/peer-state.json"; }

@test "the stubs actually execute — a dead stub would fake every answer" {
  run env LAUNCHCTL_MODE=running "$STUB_DIR/launchctl" print gui/501/dev.mlx-cluster.rank
  [ "$status" -eq 0 ]
  [[ "$output" == *"state = running"* ]]
  run "$STUB_DIR/curl" -X GET "https://stub.invalid/api/v1/labels"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"maintenance"'* ]]
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

@test "link up and armed opens a window even with the rank down" {
  set_link up
  set_peer '{"armed": true}'
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  [ "$(state)" = "9001" ]
  [[ "$output" == *"link-state up, peer armed"* ]]
}

@test "link up with the peer not armed is free, and nothing is sent" {
  set_link up
  set_peer '{"armed": false}'
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
  [ ! -s "$CALLS" ]
}

@test "link down with the peer still armed closes an open window" {
  LAUNCHCTL_MODE=running reconcile
  : > "$CALLS"
  set_link down
  set_peer '{"armed": true}'
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  grep -q "POST /tasks/9001" "$CALLS"
  [ -z "$(state)" ]
}

@test "unreadable peer state keeps an open window open" {
  LAUNCHCTL_MODE=running reconcile
  : > "$CALLS"
  set_link up
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  [ "$(state)" = "9001" ]
  grep -q "POST /tasks/9001" "$CALLS"
  [[ "$output" == *"peer-state.json unreadable"* ]]
  [[ "$output" != *"closed window"* ]]
}

@test "peer state the gate cannot read as one armed flag counts as clustered" {
  set_link up
  set_peer 'armed'
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  [ "$(state)" = "9001" ]
  [[ "$output" == *"does not hold one armed flag"* ]]
}

@test "an update posts the whole task back, so the description survives" {
  LAUNCHCTL_MODE=running reconcile
  : > "$BODIES"
  LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  grep -q '"description":"keep this description"' "$BODIES"
  grep -q '"title":"host.example"' "$BODIES"
  ! grep -q '2000-01-01' "$BODIES"
}

@test "a close posts the whole task back with done set, and keeps the description" {
  LAUNCHCTL_MODE=running reconcile
  : > "$BODIES"
  LAUNCHCTL_MODE=stopped reconcile
  [ "$status" -eq 0 ]
  grep -q '"done":true' "$BODIES"
  grep -q '"description":"keep this description"' "$BODIES"
}

@test "a task that does not come back as itself is never posted to" {
  LAUNCHCTL_MODE=running reconcile
  : > "$BODIES"
  TASK_JSON='{}' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [ ! -s "$BODIES" ]
  [ "$(state)" = "9001" ]
}

@test "a transient refresh failure keeps the id, so no duplicate window opens" {
  LAUNCHCTL_MODE=running reconcile
  FAIL_PATH='/tasks/9001' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"keeping the id"* ]]
  [ "$(state)" = "9001" ]
  [ "$(grep -c '^PUT /projects/54/tasks$' "$CALLS")" -eq 1 ]
}

@test "a refresh of a deleted window task forgets the id" {
  LAUNCHCTL_MODE=running reconcile
  HTTP_CODE=404 FAIL_PATH='/tasks/9001' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"no longer exists"* ]]
  [ -z "$(state)" ]
}

@test "a refresh reopens a window closed by hand while still clustered" {
  LAUNCHCTL_MODE=running reconcile
  : > "$BODIES"
  TASK_JSON='{"id":9001,"title":"host.example","description":"keep this description","done":true,"due_date":"2000-01-01T00:00:00Z","labels":[]}' \
    LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  grep -q '"done":false' "$BODIES"
  grep -q '"description":"keep this description"' "$BODIES"
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

@test "a create the API refuses is loud, non-fatal, and records nothing" {
  FAIL_PATH='/projects/54/tasks' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"could NOT open a maintenance window"* ]]
  [ -z "$(state)" ]
}

@test "each API call is attempted the configured number of times, then deferred" {
  MLX_CLUSTER_WINDOW_ATTEMPTS=3 FAIL_PATH='/projects/54/tasks' LAUNCHCTL_MODE=running reconcile
  [ "$(grep -c 'PUT /projects/54/tasks' "$CALLS")" -eq 3 ]
}

@test "a label that cannot be resolved leaves the window open and says so" {
  FAIL_PATH='/labels' LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [ "$(state)" = "9001" ]
  [[ "$output" == *"could not resolve a label"* ]]
}

@test "a missing API URL logs and exits 0 without an API call" {
  VIKUNJA_API_URL="" LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"VIKUNJA_API_URL not set"* ]]
  [ ! -s "$CALLS" ]
}

@test "a missing token logs and exits 0 without an API call" {
  VIKUNJA_API_TOKEN="" LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"no VIKUNJA_API_TOKEN"* ]]
  [ ! -s "$CALLS" ]
  [ -z "$(state)" ]
}

@test "no GUI launchd domain is treated as not clustered, and logged as undetermined" {
  MLX_CLUSTER_GUI_UID=0 LAUNCHCTL_MODE=running reconcile
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNDETERMINED"* ]]
  [[ "$output" == *"nothing to do"* ]]
}
