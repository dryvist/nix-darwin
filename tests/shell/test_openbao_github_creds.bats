#!/usr/bin/env bats
#
# openbao-github-creds --self-check, driven against a stub OpenBao. No network.
#
# The seam under test is the ONE place this script may legitimately decline to
# run a check: the GITHUB_WRITE lock-reacquire probe. Two states reach it and
# they must not be conflated.
#
#   never configured on this machine  -> SKIP, and the run still passes
#   configured, but the login failed  -> FAIL, loudly
#
# The second used to be reported as the first: when the server could not
# complete a login, `--self-check` printed an error, then a SKIP, then
# "self-check OK", and exited 0. A self-check that answers OK while the
# credential path is unusable is worse than none, because a monitor believes
# it.
#
# The cause was a single line: `|| { echo SKIP; return 0; }` attached to the
# login itself. That both switched errexit off for the command and rewrote the
# verdict, so one construct suppressed the abort and reported success.

bats_require_minimum_version 1.5.0 # for `run --separate-stderr`

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

# Stubs get the shebang of the bash actually running the suite, matching the
# convention in test_openbao_slack_creds.bats: `/usr/bin/env` is not available
# in the Nix build sandbox these tests run in, and a stub that fails to exec
# would silently answer every call the same way.
write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB_DIR"
  PATH="$STUB_DIR:$PATH"
  # A syntactically valid address that is never dialled — every curl is stubbed.
  export BAO_ADDR="http://openbao.invalid"
  export OPENBAO_GITHUB_DRYVIST_INSTALLATION_ID=147266792
  unset OPENBAO_APPROLE_GITHUB_WRITE_ROLE_ID OPENBAO_APPROLE_GITHUB_WRITE_SECRET_ID
  unset OPENBAO_GITHUB_WRITE_SCOPES
}

# curl exits 22 the way `curl -sf` does on an HTTP error, and non-zero the way
# it does on a timeout — the login cannot complete either way, which is the
# only property these tests depend on.
stub_curl_always_fails() {
  write_stub "$STUB_DIR/curl" <<'SH'
exit 22
SH
}

# Invoked exactly as writeShellApplication wraps it in production: that wrapper
# supplies `set -euo pipefail`, and the raw source deliberately omits its own
# set line. Running it bare here would test a shell the script never meets.
run_creds() { run --separate-stderr bash -euo pipefail "$SCRIPTS/openbao-github-creds.sh" "$@"; }

@test "GITHUB_WRITE configured but its login fails: self-check FAILS, never prints OK" {
  export OPENBAO_APPROLE_GITHUB_WRITE_ROLE_ID=role-abc
  export OPENBAO_APPROLE_GITHUB_WRITE_SECRET_ID=secret-abc
  stub_curl_always_fails

  run_creds --self-check

  [ "$status" -ne 0 ]
  # The verdict line is the whole point: a monitor reads this, not the stderr.
  [[ "$output" != *"self-check OK"* ]]
  [[ "$output" == *"self-check FAIL"* ]]
  # And it must not be dressed up as an absence, which is what hid the outage.
  [[ "$output" != *"self-check SKIP"* ]]
}

@test "GITHUB_WRITE not configured at all: still SKIPs and still passes" {
  # The legitimate skip. A machine that was never given the write credential is
  # not broken, and this check must stay quiet there or it becomes noise that
  # gets ignored — which is the other way to lose a real signal.
  stub_curl_always_fails

  run_creds --self-check

  [ "$status" -eq 0 ]
  [[ "$output" == *"self-check SKIP"* ]]
  [[ "$output" == *"self-check OK"* ]]
}

@test "the skip decision is made before any login is attempted" {
  # Distinguishes this design from one that still tries the login and then
  # inspects the failure: with no credential there is nothing to authenticate
  # with, so dialling out at all is wrong. Recording every curl invocation is
  # how we tell the two apart.
  write_stub "$STUB_DIR/curl" <<SH
echo "called" >> "$BATS_TEST_TMPDIR/curl-calls"
exit 22
SH

  run_creds --self-check

  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TEST_TMPDIR/curl-calls" ]
}

@test "AppRole login sends role_id/secret_id on stdin, never in argv" {
  # argv is visible to any local process via `ps`; a JSON body built with
  # `curl -d "...${secret_id}..."` leaks the credential there. The fix routes
  # the body through stdin (--data-binary @-) instead — this asserts the
  # secret never appears in the recorded argv and DOES appear on stdin, so
  # the check fails if a future edit reintroduces the argv form.
  export OPENBAO_APPROLE_GITHUB_WRITE_ROLE_ID=role-abc
  export OPENBAO_APPROLE_GITHUB_WRITE_SECRET_ID=secret-abc-DO-NOT-LEAK
  write_stub "$STUB_DIR/curl" <<'SH'
for a in "$@"; do echo "$a" >> "$BATS_TEST_TMPDIR/curl-argv"; done
case " $* " in
  *"auth/approle/login"*)
    cat > "$BATS_TEST_TMPDIR/curl-stdin"
    echo '{"auth":{"client_token":"tok-123"}}'
    exit 0
    ;;
esac
exit 22
SH

  run_creds --self-check

  [ -f "$BATS_TEST_TMPDIR/curl-argv" ]
  ! grep -q "secret-abc-DO-NOT-LEAK" "$BATS_TEST_TMPDIR/curl-argv"
  [ -f "$BATS_TEST_TMPDIR/curl-stdin" ]
  grep -q "secret-abc-DO-NOT-LEAK" "$BATS_TEST_TMPDIR/curl-stdin"
}
