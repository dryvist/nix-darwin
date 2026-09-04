#!/usr/bin/env bats
#
# openbao-aws-creds, driven against a stub OpenBao — no network.
#
# Two regressions this covers:
#   1. AppRole role_id/secret_id used to travel as a `curl -d "{...}"` argv
#      string, visible to any local process via `ps`. Fixed to travel on
#      stdin (--data-binary @-), mirroring openbao-github-creds.sh.
#   2. The mkdir-based cache lock used to force-reclaim after ~10s
#      unconditionally — evicting a holder that was merely slow, not dead,
#      producing two processes that both believe they hold the lock. Fixed
#      to reclaim only when the lock's recorded PID is provably dead.

bats_require_minimum_version 1.5.0 # for `run --separate-stderr`

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

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
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export VAULT_ADDR="http://openbao.invalid"
  export OPENBAO_APPROLE_TERRAFORM_ROLE_ID=role-abc
  export OPENBAO_APPROLE_TERRAFORM_SECRET_ID=secret-abc-DO-NOT-LEAK
}

run_creds() { run --separate-stderr bash -euo pipefail "$SCRIPTS/openbao-aws-creds.sh" "$@"; }

@test "AppRole login sends role_id/secret_id on stdin, never in argv" {
  write_stub "$STUB_DIR/curl" <<'SH'
for a in "$@"; do echo "$a" >> "$BATS_TEST_TMPDIR/curl-argv"; done
case " $* " in
  *"auth/approle/login"*)
    cat > "$BATS_TEST_TMPDIR/curl-stdin"
    echo '{"auth":{"client_token":"tok-123"}}'
    exit 0
    ;;
  *"aws/sts/"*)
    echo '{"data":{"access_key":"AKIA","secret_key":"sk","security_token":"st"},"lease_duration":3600}'
    exit 0
    ;;
esac
exit 22
SH

  run_creds tf-proxmox

  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/curl-argv" ]
  ! grep -q "secret-abc-DO-NOT-LEAK" "$BATS_TEST_TMPDIR/curl-argv"
  [ -f "$BATS_TEST_TMPDIR/curl-stdin" ]
  grep -q "secret-abc-DO-NOT-LEAK" "$BATS_TEST_TMPDIR/curl-stdin"
  [[ "$output" == *"AccessKeyId"* ]]
}

@test "a lock held by a live process is never force-evicted" {
  # Pre-create the lock dir with the PID of a process that is still alive
  # (this test itself). The script must refuse rather than reclaim.
  mkdir -p "$HOME/.cache/openbao-aws"
  lock_dir="$HOME/.cache/openbao-aws/tf-proxmox.json.lock"
  mkdir -p "$lock_dir"
  echo "$$" > "$lock_dir/pid"

  run_creds tf-proxmox

  [ "$status" -ne 0 ]
  [[ "$stderr" == *"refusing to force-evict a live holder"* ]]
  # The live holder's lock must survive — nothing else acquired or removed it.
  [ -d "$lock_dir" ]
}

@test "a lock held by a dead process is reclaimed and the mint proceeds" {
  mkdir -p "$HOME/.cache/openbao-aws"
  lock_dir="$HOME/.cache/openbao-aws/tf-proxmox.json.lock"
  mkdir -p "$lock_dir"
  # A pid guaranteed not to be running: fork a subshell and capture its pid
  # after it has already exited.
  ( : ) & dead_pid=$!
  wait "$dead_pid" || true
  echo "$dead_pid" > "$lock_dir/pid"

  write_stub "$STUB_DIR/curl" <<'SH'
case " $* " in
  *"auth/approle/login"*) echo '{"auth":{"client_token":"tok-123"}}'; exit 0 ;;
  *"aws/sts/"*) echo '{"data":{"access_key":"AKIA","secret_key":"sk","security_token":"st"},"lease_duration":3600}'; exit 0 ;;
esac
exit 22
SH

  run_creds tf-proxmox

  [ "$status" -eq 0 ]
  [[ "$output" == *"AccessKeyId"* ]]
}
