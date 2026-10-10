#!/usr/bin/env bats
#
# darwin-rebuild-windowed, run against stub curl, logger and darwin-rebuild.
# Each test asserts the exit status, whether darwin-rebuild ran and with which
# arguments, and the logged decision. No network and no root are needed.

bats_require_minimum_version 1.5.0 # for `run --separate-stderr`

SCRIPT="$BATS_TEST_DIRNAME/../../modules/darwin/scripts/darwin-rebuild-windowed.sh"

GOOD_WINDOW='{"data":{"policies":["default","ai-admin"],"meta":{"role_name":"ai-admin-session"},"ttl":3600}}'

# Stubs take the shebang of the bash running the suite: /usr/bin/env is not
# available in the Nix build sandbox (see test_cluster_rebuild_gate.bats).
write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  CLUSTER_DIR="$BATS_TEST_TMPDIR/cluster"
  mkdir -p "$STUB_DIR" "$CLUSTER_DIR"
  export CURL_CALLS="$BATS_TEST_TMPDIR/curl-argv"
  export DR_ARGS="$BATS_TEST_TMPDIR/darwin-rebuild-argv"
  export SYSLOG="$BATS_TEST_TMPDIR/syslog"
  : > "$CURL_CALLS"
  : > "$DR_ARGS"
  : > "$SYSLOG"

  # A unix socket path is limited to 104 bytes on macOS, so the socket sits in
  # a short, unique directory under /tmp rather than under BATS_TEST_TMPDIR.
  SOCK_ROOT="$(mktemp -d /tmp/dw-sock.XXXXXX)"
  chmod 700 "$SOCK_ROOT"
  export SOCKET="$SOCK_ROOT/proxy.sock"
  python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$SOCKET"

  # curl stub: emulates the window proxy. It accepts only lookup-self over the
  # configured socket, and it fails on any header, since the wrapper must send
  # no token. The reply comes from LOOKUP_BODY and exit code from LOOKUP_RC.
  write_stub "$STUB_DIR/curl" << 'STUB'
printf '%s\n' "$*" >> "$CURL_CALLS"
socket=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --unix-socket) socket="$2"; shift 2 ;;
    --max-time) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
[ "$socket" = "$SOCKET" ] && [ "$url" = "http://localhost/v1/auth/token/lookup-self" ] || exit 22
printf '%s' "$LOOKUP_BODY"
exit "${LOOKUP_RC:-0}"
STUB

  # logger stub: records "<tag>: <message>" in the syslog trail.
  write_stub "$STUB_DIR/logger" << 'STUB'
printf '%s: %s\n' "$2" "$3" >> "$SYSLOG"
STUB

  # darwin-rebuild stub: records its arguments and exits with DR_RC (default 0).
  write_stub "$STUB_DIR/darwin-rebuild" << 'STUB'
printf '%s\n' "$*" >> "$DR_ARGS"
exit "${DR_RC:-0}"
STUB

  export LOOKUP_BODY="$GOOD_WINDOW"
  export DARWIN_REBUILD_WINDOWED_WINDOW_SOCKET="$SOCKET"
  export DARWIN_REBUILD_WINDOWED_OWNER_UID="$(id -u)"
  export DARWIN_REBUILD_WINDOWED_CLUSTER_STATE_DIR="$CLUSTER_DIR"
  export DARWIN_REBUILD_WINDOWED_DARWIN_REBUILD_BIN="$STUB_DIR/darwin-rebuild"
  export DARWIN_REBUILD_WINDOWED_CURL_BIN="$STUB_DIR/curl"
  export DARWIN_REBUILD_WINDOWED_LOGGER_BIN="$STUB_DIR/logger"
  export DARWIN_REBUILD_WINDOWED_FLAKE_REF="github:example/host-config"
  export DARWIN_REBUILD_WINDOWED_TRUSTED_UID="$(id -u)"
}

teardown() {
  rm -rf "$SOCK_ROOT"
}

# run_wrapper [hostname args...]: runs the wrapper. It reads no stdin.
run_wrapper() {
  run --separate-stderr bash -euo pipefail "$SCRIPT" "$@"
}

# logged <substring>: the syslog trail contains that text.
logged() {
  grep -qF -- "$1" "$SYSLOG"
}

@test "a good window on an unclustered host runs darwin-rebuild with the fixed arguments" {
  run_wrapper test-host
  [ "$status" -eq 0 ]
  [ "$(cat "$DR_ARGS")" = "switch --flake github:example/host-config#test-host --refresh" ]
  logged "darwin-rebuild-windowed: window accepted"
  logged "darwin-rebuild-windowed: run: darwin-rebuild switch"
}

@test "the lookup-self request goes to the configured socket and sends no token" {
  run_wrapper test-host
  [ "$status" -eq 0 ]
  grep -qF -- "--unix-socket $SOCKET http://localhost/v1/auth/token/lookup-self" "$CURL_CALLS"
  run grep -qE -- '(^| )-H( |$)|X-Vault-Token' "$CURL_CALLS"
  [ "$status" -ne 0 ]
}

@test "a socket that rejects lookup-self is denied and darwin-rebuild does not run" {
  export LOOKUP_RC=22
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window socket rejected lookup-self, or the proxy did not answer"
}

@test "a window without the ai-admin policy is denied" {
  export LOOKUP_BODY='{"data":{"policies":["default"],"meta":{"role_name":"ai-admin-session"},"ttl":3600}}'
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window lacks the ai-admin policy"
}

@test "a window for a different role is denied" {
  export LOOKUP_BODY='{"data":{"policies":["ai-admin"],"meta":{"role_name":"other-role"},"ttl":3600}}'
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window is not the ai-admin-session role"
}

@test "display_name alone does not name the role, so the window is denied" {
  export LOOKUP_BODY='{"data":{"policies":["ai-admin"],"display_name":"ai-admin-session","ttl":3600}}'
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window is not the ai-admin-session role"
}

@test "a non-expiring window (ttl 0) is denied" {
  export LOOKUP_BODY='{"data":{"policies":["ai-admin"],"meta":{"role_name":"ai-admin-session"},"ttl":0}}'
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window has no ttl above zero"
}

@test "a socket directory that other uids can write is denied before the socket is contacted" {
  chmod 777 "$SOCK_ROOT"
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window socket's directory is not owned by the owner uid, or others can write it"
}

@test "a socket that other uids can write is denied before it is contacted" {
  chmod 666 "$SOCKET"
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  logged "DENY: window socket is not a socket owned by the owner uid, or others can write it"
}

@test "a socket owned by another uid is denied before it is contacted" {
  export DARWIN_REBUILD_WINDOWED_OWNER_UID=$(( $(id -u) + 1 ))
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window socket is not a socket owned by the owner uid, or others can write it"
}

@test "a path that is a regular file rather than a socket is denied" {
  rm "$SOCKET"
  : > "$SOCKET"
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  logged "DENY: window socket is not a socket owned by the owner uid, or others can write it"
}

@test "a clustered host (link up, peer armed) is refused and darwin-rebuild does not run" {
  printf 'up\n' > "$CLUSTER_DIR/link-state"
  printf '{"armed": true}\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: cluster: link-state up and peer armed, host is clustered"
}

@test "a link that is down, or a peer that is not armed, is not clustered" {
  printf 'down\n' > "$CLUSTER_DIR/link-state"
  printf '{"armed": true}\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper test-host
  [ "$status" -eq 0 ]
  : > "$DR_ARGS"
  printf 'up\n' > "$CLUSTER_DIR/link-state"
  printf '{"armed": false}\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper test-host
  [ "$status" -eq 0 ]
}

@test "absent cluster state is treated as not clustered" {
  run_wrapper test-host
  [ "$status" -eq 0 ]
  logged "cluster: state files absent, treated as not clustered"
}

@test "cluster state that cannot be interpreted is refused" {
  printf 'up\n' > "$CLUSTER_DIR/link-state"
  printf 'not json\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: cluster: peer-state.json is unreadable or not JSON"
  printf 'maybe\n' > "$CLUSTER_DIR/link-state"
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: cluster: link-state holds an unexpected value"
}

@test "extra arguments are denied before the socket is contacted" {
  run_wrapper test-host extra
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: expected exactly one argument, the hostname (got 2)"
}

@test "no argument is denied" {
  run_wrapper
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: expected exactly one argument, the hostname (got 0)"
}

@test "a hostname outside lowercase letters, digits and hyphens is denied" {
  local h
  for h in Test-Host 'host;id' 'a.b' ''; do
    run_wrapper "$h"
    [ "$status" -eq 1 ]
  done
  [ ! -s "$DR_ARGS" ]
}

@test "a run under a uid other than the trusted uid is denied before any other check" {
  export DARWIN_REBUILD_WINDOWED_TRUSTED_UID=$(( $(id -u) + 1 ))
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  logged "DENY: not running as the trusted uid"
}

@test "a run returns darwin-rebuild's exit status" {
  export DR_RC=7
  run_wrapper test-host
  [ "$status" -eq 7 ]
  logged "darwin-rebuild-windowed: run: darwin-rebuild exited with 7"
}

@test "every denial is echoed to stderr as well as logged" {
  export LOOKUP_BODY='{"data":{"policies":["default"],"meta":{"role_name":"ai-admin-session"},"ttl":3600}}'
  run_wrapper test-host
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"DENY: window lacks the ai-admin policy"* ]]
}
