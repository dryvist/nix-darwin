#!/usr/bin/env bats
#
# darwin-rebuild-windowed, run against stub curl, logger and darwin-rebuild.
# Each test asserts the exit status, whether darwin-rebuild ran and with which
# arguments, and the logged decision. No network and no root are needed.

bats_require_minimum_version 1.5.0 # for `run --separate-stderr`

SCRIPT="$BATS_TEST_DIRNAME/../../modules/darwin/scripts/darwin-rebuild-windowed.sh"

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
  BAO_DIR="$BATS_TEST_TMPDIR/bao"
  CLUSTER_DIR="$BATS_TEST_TMPDIR/cluster"
  mkdir -p "$STUB_DIR" "$CLUSTER_DIR"
  mkdir -m 700 "$BAO_DIR"
  export CURL_CALLS="$BATS_TEST_TMPDIR/curl-argv"
  export DR_ARGS="$BATS_TEST_TMPDIR/darwin-rebuild-argv"
  export SYSLOG="$BATS_TEST_TMPDIR/syslog"
  : > "$CURL_CALLS"
  : > "$DR_ARGS"
  : > "$SYSLOG"

  printf 'BAO_ADDR=https://bao.example.test:8200\n' > "$BAO_DIR/bao-addr"
  chmod 600 "$BAO_DIR/bao-addr"

  # curl stub: the header arrives as -H @<fd>, which is read here. The reply
  # depends on the token, and the argv is recorded so a test can show that the
  # token never travels in argv.
  write_stub "$STUB_DIR/curl" << 'STUB'
printf '%s\n' "$*" >> "$CURL_CALLS"
hdr=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -H) hdr="${2#@}"; shift 2 ;;
    --max-time) shift 2 ;;
    *) shift ;;
  esac
done
token="$(sed -n 's/^X-Vault-Token: //p' "$hdr")"
case "$token" in
  good-token) printf '%s' '{"data":{"policies":["default","ai-admin"],"meta":{"role_name":"ai-admin-session"},"ttl":3600}}' ;;
  no-policy-token) printf '%s' '{"data":{"policies":["default"],"meta":{"role_name":"ai-admin-session"},"ttl":3600}}' ;;
  wrong-role-token) printf '%s' '{"data":{"policies":["ai-admin"],"meta":{"role_name":"other-role"},"ttl":3600}}' ;;
  display-name-token) printf '%s' '{"data":{"policies":["ai-admin"],"display_name":"ai-admin-session","ttl":3600}}' ;;
  no-expiry-token) printf '%s' '{"data":{"policies":["ai-admin"],"meta":{"role_name":"ai-admin-session"},"ttl":0}}' ;;
  *) exit 22 ;;
esac
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

  export DARWIN_REBUILD_WINDOWED_BAO_ADDR_FILE="$BAO_DIR/bao-addr"
  export DARWIN_REBUILD_WINDOWED_CLUSTER_STATE_DIR="$CLUSTER_DIR"
  export DARWIN_REBUILD_WINDOWED_DARWIN_REBUILD_BIN="$STUB_DIR/darwin-rebuild"
  export DARWIN_REBUILD_WINDOWED_CURL_BIN="$STUB_DIR/curl"
  export DARWIN_REBUILD_WINDOWED_LOGGER_BIN="$STUB_DIR/logger"
  export DARWIN_REBUILD_WINDOWED_FLAKE_REF="github:example/host-config"
  export DARWIN_REBUILD_WINDOWED_TRUSTED_UID="$(id -u)"
}

# run_wrapper <token> [hostname args...]: the token reaches the wrapper on
# stdin. It is never an argument.
run_wrapper() {
  export TOKEN="$1"
  shift
  run --separate-stderr bash -c 'printf "%s\n" "$TOKEN" | exec bash -euo pipefail "$0" "$@"' "$SCRIPT" "$@"
}

# logged <substring>: the syslog trail contains that text.
logged() {
  grep -qF -- "$1" "$SYSLOG"
}

@test "a good window token on an unclustered host runs darwin-rebuild with the fixed arguments" {
  run_wrapper good-token test-host
  [ "$status" -eq 0 ]
  [ "$(cat "$DR_ARGS")" = "switch --flake github:example/host-config#test-host --refresh" ]
  logged "darwin-rebuild-windowed: window token accepted"
  logged "darwin-rebuild-windowed: run: darwin-rebuild switch"
}

@test "a rejected window token is denied and darwin-rebuild does not run" {
  run_wrapper bogus-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window token rejected, or OpenBao did not answer lookup-self"
}

@test "a token without the ai-admin policy is denied" {
  run_wrapper no-policy-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window token lacks the ai-admin policy"
}

@test "a token for a different role is denied" {
  run_wrapper wrong-role-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window token is not the ai-admin-session role"
}

@test "display_name is the role when meta carries no role_name" {
  run_wrapper display-name-token test-host
  [ "$status" -eq 0 ]
}

@test "a non-expiring token (ttl 0) is denied" {
  run_wrapper no-expiry-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: window token has no ttl above zero"
}

@test "a clustered host (link up, peer armed) is refused and darwin-rebuild does not run" {
  printf 'up\n' > "$CLUSTER_DIR/link-state"
  printf '{"armed": true}\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper good-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: cluster: link-state up and peer armed, host is clustered"
}

@test "a link that is down, or a peer that is not armed, is not clustered" {
  printf 'down\n' > "$CLUSTER_DIR/link-state"
  printf '{"armed": true}\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper good-token test-host
  [ "$status" -eq 0 ]
  : > "$DR_ARGS"
  printf 'up\n' > "$CLUSTER_DIR/link-state"
  printf '{"armed": false}\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper good-token test-host
  [ "$status" -eq 0 ]
}

@test "absent cluster state is treated as not clustered" {
  run_wrapper good-token test-host
  [ "$status" -eq 0 ]
  logged "cluster: state files absent, treated as not clustered"
}

@test "cluster state that cannot be interpreted is refused" {
  printf 'up\n' > "$CLUSTER_DIR/link-state"
  printf 'not json\n' > "$CLUSTER_DIR/peer-state.json"
  run_wrapper good-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: cluster: peer-state.json is unreadable or not JSON"
  printf 'maybe\n' > "$CLUSTER_DIR/link-state"
  run_wrapper good-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: cluster: link-state holds an unexpected value"
}

@test "extra arguments are denied before the token is read or sent to OpenBao" {
  run_wrapper good-token test-host extra
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: expected exactly one argument, the hostname (got 2)"
}

@test "no argument is denied" {
  run_wrapper good-token
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: expected exactly one argument, the hostname (got 0)"
}

@test "a hostname outside lowercase letters, digits and hyphens is denied" {
  local h
  for h in Test-Host 'host;id' 'a.b' ''; do
    run_wrapper good-token "$h"
    [ "$status" -eq 1 ]
  done
  [ ! -s "$DR_ARGS" ]
}

@test "empty stdin is denied as a missing token" {
  run bash -c 'exec bash -euo pipefail "$0" test-host < /dev/null' "$SCRIPT"
  [ "$status" -eq 1 ]
  logged "DENY: no well-formed window token on stdin"
}

@test "a token containing a space is denied as malformed" {
  run_wrapper 'good-token extra' test-host
  [ "$status" -eq 1 ]
  logged "DENY: no well-formed window token on stdin"
}

@test "a token longer than 512 characters is denied as malformed" {
  local long
  long="$(printf 'a%.0s' {1..600})"
  run_wrapper "$long" test-host
  [ "$status" -eq 1 ]
  logged "DENY: no well-formed window token on stdin"
}

@test "the window token never appears in the argv of a child process" {
  run_wrapper good-token test-host
  [ "$status" -eq 0 ]
  run grep -qF good-token "$CURL_CALLS"
  [ "$status" -ne 0 ]
  run grep -qF good-token "$DR_ARGS"
  [ "$status" -ne 0 ]
}

@test "an OpenBao address file that other uids can write is denied" {
  chmod 666 "$BAO_DIR/bao-addr"
  run_wrapper good-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  logged "DENY: OpenBao address file is not owned by the trusted uid, or others can write it"
}

@test "an OpenBao address that is not https is denied" {
  printf 'BAO_ADDR=http://bao.example.test:8200\n' > "$BAO_DIR/bao-addr"
  run_wrapper good-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$DR_ARGS" ]
  logged "DENY: BAO_ADDR is missing or is not an https URL"
}

@test "a run under a uid other than the trusted uid is denied before any other check" {
  export DARWIN_REBUILD_WINDOWED_TRUSTED_UID=$(( $(id -u) + 1 ))
  run_wrapper good-token test-host
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_CALLS" ]
  logged "DENY: not running as the trusted uid"
}

@test "a run returns darwin-rebuild's exit status" {
  export DR_RC=7
  run_wrapper good-token test-host
  [ "$status" -eq 7 ]
  logged "darwin-rebuild-windowed: run: darwin-rebuild exited with 7"
}

@test "every denial is echoed to stderr as well as logged" {
  run_wrapper bogus-token test-host
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"DENY: window token rejected"* ]]
}
