#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

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
  export CALLS="$BATS_TEST_TMPDIR/az-calls"
  export LOGIN_COUNT="$BATS_TEST_TMPDIR/az-login-count"
  : > "$CALLS"

  export ROLE="role-$BATS_TEST_NUMBER"
  ROLE_ENV="$(printf '%s' "$ROLE" | tr '[:lower:]-' '[:upper:]_')"
  export ROLE_ID_ENV="OPENBAO_APPROLE_AZURE_${ROLE_ENV}_ROLE_ID"
  export SECRET_ID_ENV="OPENBAO_APPROLE_AZURE_${ROLE_ENV}_SECRET_ID"
  export TEST_ROLE_ID="approle-id-$BATS_TEST_NUMBER"
  export TEST_SECRET_ID="approle-secret-$BATS_TEST_NUMBER"
  export TEST_WRAPPED_TOKEN="wrapped-$BATS_TEST_NUMBER"
  export TEST_WRAPPED_SECRET_ID="wrapped-secret-$BATS_TEST_NUMBER"
  export TEST_OPENBAO_TOKEN="openbao-token-$BATS_TEST_NUMBER"
  export TEST_CLIENT_ID="client-$BATS_TEST_NUMBER"
  export TEST_CLIENT_SECRET="client-secret-$BATS_TEST_NUMBER"
  export OPENBAO_AZURE_TENANT_ID="tenant-$BATS_TEST_NUMBER"
  export BAO_ADDR="https://example.invalid"
  export AZURE_DEVOPS_EXT_PAT="unused-pat"
  export LOGIN_FAILURES=0
  export "$ROLE_ID_ENV=$TEST_ROLE_ID"
  export "$SECRET_ID_ENV=$TEST_SECRET_ID"

  write_stub "$STUB_DIR/bao" <<'STUB'
case "$1" in
  unwrap)
    [ "${BAO_TOKEN:-}" = "$TEST_WRAPPED_TOKEN" ] || exit 20
    printf '{"data":{"secret_id":"%s"}}\n' "$TEST_WRAPPED_SECRET_ID"
    ;;
  write)
    [ "$3" = auth/approle/login ] || exit 21
    body="$(cat)"
    [[ "$body" == *"$TEST_ROLE_ID"* && "$body" == *"${EXPECT_SECRET_ID:-$TEST_SECRET_ID}"* ]] || exit 22
    printf '{"auth":{"client_token":"%s"}}\n' "$TEST_OPENBAO_TOKEN"
    ;;
  read)
    [ "${BAO_TOKEN:-}" = "$TEST_OPENBAO_TOKEN" ] || exit 23
    [ "$3" = "azure/creds/$ROLE" ] || exit 24
    printf '{"data":{"client_id":"%s","client_secret":"%s"}}\n' \
      "$TEST_CLIENT_ID" "$TEST_CLIENT_SECRET"
    ;;
  *) exit 25 ;;
esac
STUB

  write_stub "$STUB_DIR/az" <<'STUB'
case "$1" in
  login)
    [ -d "$AZURE_CONFIG_DIR" ] || exit 30
    [ "${AZURE_DEVOPS_EXT_PAT+x}" != x ] || exit 31
    [ "$4" = "$TEST_CLIENT_ID" ] || exit 32
    [ "$6" = "$TEST_CLIENT_SECRET" ] || exit 33
    count=0
    [ ! -f "$LOGIN_COUNT" ] || count="$(cat "$LOGIN_COUNT")"
    count=$((count + 1))
    printf '%s' "$count" > "$LOGIN_COUNT"
    printf 'login\n' >> "$CALLS"
    [ "$count" -gt "$LOGIN_FAILURES" ]
    ;;
  logout)
    printf 'logout\n' >> "$CALLS"
    ;;
  *) exit 34 ;;
esac
STUB

  write_stub "$STUB_DIR/sleep" <<'STUB'
exit 0
STUB
}

run_wrapper() {
  run --separate-stderr env PATH="$STUB_DIR:$PATH" bash -euo pipefail \
    "$SCRIPTS/openbao-azure-creds.sh" "$ROLE" sh -c \
    'printenv AZURE_CONFIG_DIR; ! printenv AZURE_DEVOPS_EXT_PAT; ! printenv OPENBAO_AZURE_TENANT_ID'
}

@test "uses ambient AppRole values and cleans the Azure CLI config" {
  export LOGIN_FAILURES=1
  run_wrapper

  [ "$status" -eq 0 ]
  [ "$(cat "$LOGIN_COUNT")" -eq 2 ]
  [ "$(cat "$CALLS")" = $'login\nlogin\nlogout' ]
  [ ! -e "$output" ]
  [[ "$stderr" == *"retrying in 10 seconds"* ]]
  [[ "$output" != *"$TEST_CLIENT_SECRET"* ]]
}

@test "unwraps the caller-provided secret ID" {
  unset "$SECRET_ID_ENV"
  export OPENBAO_AZURE_WRAPPED_SECRET_ID="$TEST_WRAPPED_TOKEN"
  export EXPECT_SECRET_ID="$TEST_WRAPPED_SECRET_ID"
  run_wrapper

  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = $'login\nlogout' ]
  [ ! -e "$output" ]
  [[ "$output" != *"$TEST_CLIENT_SECRET"* ]]
}
