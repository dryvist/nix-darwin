#!/usr/bin/env bats
#
# comin-token-reload, driven against a stub comin and a stub launchctl. The cases that matter:
# a changed token restarts an idle comin; fetching, evaluating, building or deploying defers the
# restart; and an unreadable comin state still restarts (a comin that cannot answer reports no work).

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

# Stubs get the shebang of the bash running the suite; /usr/bin/env is absent in the Nix build sandbox.
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
  write_stub "$STUB_DIR/comin" << 'STUB'
echo "comin $*" >> "$CALLS"
[ "${COMIN_STATUS_FAIL:-}" = 1 ] && { echo "connection refused" >&2; exit 1; }
printf '%s' "$COMIN_STATUS"
STUB
  write_stub "$STUB_DIR/launchctl" << 'STUB'
echo "launchctl $*" >> "$CALLS"
STUB
  export PATH="$STUB_DIR:$PATH"
  export COMIN_LABEL=com.github.nlewo.comin
  export LAUNCHCTL="$STUB_DIR/launchctl"
  export COMIN_TOKEN_PATH="$BATS_TEST_TMPDIR/token"
  : > "$COMIN_TOKEN_PATH"
}

run_reload() {
  run bash -euo pipefail "$SCRIPTS/comin-token-reload.sh"
}

@test "an idle comin is restarted after the token changes" {
  COMIN_STATUS='{"fetcher":{"is_fetching":false},"builder":{"is_evaluating":false,"is_building":false},"deployer":{"is_deploying":false}}' run_reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"token directory changed; restarting com.github.nlewo.comin."* ]]
  grep -qx 'launchctl kickstart -k system/com.github.nlewo.comin' "$CALLS"
}

@test "a deployment in progress defers the restart" {
  COMIN_STATUS='{"deployer":{"is_deploying":true}}' run_reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"restart deferred because comin is deploying."* ]]
  [ "$(grep -c '^launchctl' "$CALLS")" = 0 ]
}

@test "a build in progress defers the restart" {
  COMIN_STATUS='{"builder":{"is_evaluating":false,"is_building":true},"deployer":{"is_deploying":false}}' run_reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"restart deferred because comin is building."* ]]
  [ "$(grep -c '^launchctl' "$CALLS")" = 0 ]
}

@test "an evaluation in progress defers the restart" {
  COMIN_STATUS='{"builder":{"is_evaluating":true,"is_building":false}}' run_reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"restart deferred because comin is evaluating."* ]]
  [ "$(grep -c '^launchctl' "$CALLS")" = 0 ]
}

@test "a fetch in progress defers the restart" {
  COMIN_STATUS='{"fetcher":{"is_fetching":true}}' run_reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"restart deferred because comin is fetching."* ]]
  [ "$(grep -c '^launchctl' "$CALLS")" = 0 ]
}

@test "an unreadable comin state still restarts comin" {
  COMIN_STATUS_FAIL=1 run_reload
  [ "$status" -eq 0 ]
  grep -qx 'launchctl kickstart -k system/com.github.nlewo.comin' "$CALLS"
}

@test "a non-JSON comin state still restarts comin" {
  COMIN_STATUS='not json' run_reload
  [ "$status" -eq 0 ]
  grep -qx 'launchctl kickstart -k system/com.github.nlewo.comin' "$CALLS"
}

# launchd also runs the job once at load (RunAtLoad); the script cannot tell the two triggers apart,
# so these cases are the load-time run.
@test "the load-time run restarts an idle comin holding an older token" {
  COMIN_STATUS='{"fetcher":{"is_fetching":false},"deployer":{"is_deploying":false}}' run_reload
  [ "$status" -eq 0 ]
  grep -qx 'launchctl kickstart -k system/com.github.nlewo.comin' "$CALLS"
}

@test "the load-time run defers while comin is deploying" {
  COMIN_STATUS='{"deployer":{"is_deploying":true}}' run_reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"restart deferred because comin is deploying."* ]]
  [ "$(grep -c '^launchctl' "$CALLS")" = 0 ]
}

@test "no token file yet: nothing is restarted and the skip is logged" {
  rm -f "$COMIN_TOKEN_PATH"
  COMIN_STATUS='{"deployer":{"is_deploying":false}}' run_reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"no token at $COMIN_TOKEN_PATH yet; restart skipped."* ]]
  [ "$(grep -c '^launchctl' "$CALLS")" = 0 ]
  [ "$(grep -c '^comin' "$CALLS")" = 0 ]
}
