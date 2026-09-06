#!/usr/bin/env bats
#
# openbao-run, driven against a stub OpenBao KV-v2 endpoint — no network.
# Covers the seams that decide whether the wrapper is safe to hand a command:
# whole-document injection (--secrets), left-to-right override so documents
# layer, the two authentication paths (AppRole via --domain, ambient token
# without it), and every way it must fail loudly rather than exec a child with
# nothing exported.

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
  KV_DIR="$BATS_TEST_TMPDIR/kv"
  mkdir -p "$STUB_DIR" "$KV_DIR"

  # Serves KV v2 reads out of $KV_DIR (one file per mount+path, '/' -> '_') and
  # the AppRole login. An unknown path exits 22, the way `curl -f` reports a
  # 404, so a missing document is indistinguishable from the real thing.
  write_stub "$STUB_DIR/curl" << STUB
url=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -X|-H|--max-time|-o|-w|--data-binary) shift 2 ;;
    http*) url="\$1"; shift ;;
    *) shift ;;
  esac
done

case "\$url" in
  */auth/approle/login)
    if [ -n "\${LOGIN_FAIL:-}" ]; then exit 22; fi
    echo '{"auth":{"client_token":"stub-bao-token"}}'
    ;;
  */v1/*/data/*)
    rest="\${url#*/v1/}"
    mount="\${rest%%/data/*}"
    path="\${rest#*/data/}"
    file="$KV_DIR/\${mount}__\$(printf '%s' "\$path" | tr '/' '_').json"
    [ -f "\$file" ] || exit 22
    jq -c '{data: {data: .}}' "\$file"
    ;;
  *) exit 22 ;;
esac
STUB

  export OPENBAO_RUN_CURL_BIN="$STUB_DIR/curl"
  export BAO_ADDR="https://stub.invalid"
  export DEMO_VAULT_ROLE_ID="stub-role"
  export DEMO_VAULT_SECRET_ID="stub-secret"
}

# seed_doc <mount> <path> <json-object>
seed_doc() {
  printf '%s' "$3" > "$KV_DIR/${1}__$(printf '%s' "$2" | tr '/' '_').json"
}

run_bao() { run --separate-stderr bash -euo pipefail "$SCRIPTS/openbao-run.sh" "$@"; }

@test "the stub actually executes — a dead stub would fake every answer" {
  seed_doc secret app/base '{"A":"1"}'
  run "$STUB_DIR/curl" -H "X-Vault-Token: t" "https://stub.invalid/v1/secret/data/app/base"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"A":"1"'* ]]
}

@test "--secrets exports every key at the document into the exec'd command" {
  seed_doc secret app/base '{"ALPHA":"one","BETA":"two"}'
  BAO_TOKEN=t run_bao --secrets app/base -- sh -c 'echo "$ALPHA/$BETA"'
  [ "$status" -eq 0 ]
  [ "$output" = "one/two" ]
}

@test "a later --secrets overrides an earlier one, so documents layer" {
  seed_doc secret app/base '{"ALPHA":"base","BETA":"base"}'
  seed_doc secret app/over '{"BETA":"override"}'
  BAO_TOKEN=t run_bao --secrets app/base --secrets app/over -- sh -c 'echo "$ALPHA/$BETA"'
  [ "$status" -eq 0 ]
  [ "$output" = "base/override" ]
}

@test "--secret and --secrets apply strictly left to right, whichever comes last" {
  seed_doc secret app/base '{"ALPHA":"doc"}'
  seed_doc secret app/single '{"pick":"field"}'
  BAO_TOKEN=t run_bao --secret ALPHA=app/single#pick --secrets app/base -- sh -c 'echo "$ALPHA"'
  [ "$output" = "doc" ]
  BAO_TOKEN=t run_bao --secrets app/base --secret ALPHA=app/single#pick -- sh -c 'echo "$ALPHA"'
  [ "$output" = "field" ]
}

@test "a per-secret mount prefix reads that mount, leaving the default alone" {
  seed_doc secrets-external platform/x '{"EXT":"e"}'
  seed_doc secret app/base '{"ALPHA":"a"}'
  BAO_TOKEN=t run_bao --secrets secrets-external:platform/x --secrets app/base -- sh -c 'echo "$EXT/$ALPHA"'
  [ "$status" -eq 0 ]
  [ "$output" = "e/a" ]
}

@test "a value containing a newline survives intact" {
  seed_doc secret app/key '{"PRIVATE_KEY":"line1\nline2"}'
  BAO_TOKEN=t run_bao --secrets app/key -- sh -c 'echo "$PRIVATE_KEY" | wc -l'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | tr -d ' ')" = "2" ]
}

@test "a non-string value is exported as its literal text rather than dropped" {
  seed_doc secret app/num '{"PORT":8443}'
  BAO_TOKEN=t run_bao --secrets app/num -- sh -c 'echo "$PORT"'
  [ "$output" = "8443" ]
}

@test "an empty document fails loudly instead of exec'ing with nothing exported" {
  seed_doc secret app/empty '{}'
  BAO_TOKEN=t run_bao --secrets app/empty -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"no keys at secret/app/empty"* ]]
  [[ "$output" != *"ran"* ]]
}

@test "a key that is not a valid variable name is rejected, naming the key" {
  seed_doc secret app/bad '{"not-a-name":"x"}'
  BAO_TOKEN=t run_bao --secrets app/bad -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"not-a-name"* ]]
  [[ "$stderr" == *"not valid environment variable names"* ]]
}

@test "an unreadable path fails naming the path, not a generic curl error" {
  BAO_TOKEN=t run_bao --secrets app/missing -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"read failed: secret/app/missing"* ]]
  [[ "$output" != *"ran"* ]]
}

@test "a --secret naming a field the document lacks fails naming the field" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  BAO_TOKEN=t run_bao --secret X=app/base#nope -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"field 'nope'"* ]]
}

@test "no command after -- is refused" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  BAO_TOKEN=t run_bao --secrets app/base --
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"no command after -- to exec"* ]]
}

@test "no mappings at all is refused" {
  BAO_TOKEN=t run_bao -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"no --secret or --secrets mappings"* ]]
}

@test "a missing OpenBao address is refused before any request" {
  unset BAO_ADDR
  BAO_TOKEN=t run_bao --secrets app/base -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"BAO_ADDR not in environment"* ]]
}

@test "no --domain and no ambient token names both, rather than failing at the read" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  run_bao --secrets app/base -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"BAO_TOKEN/VAULT_TOKEN"* ]]
}

@test "VAULT_TOKEN is accepted as well as BAO_TOKEN" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  VAULT_TOKEN=t run_bao --secrets app/base -- sh -c 'echo "$ALPHA"'
  [ "$status" -eq 0 ]
  [ "$output" = "one" ]
}

@test "--domain authenticates with that domain's AppRole" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  run_bao --domain demo --secrets app/base -- sh -c 'echo "$ALPHA"'
  [ "$status" -eq 0 ]
  [ "$output" = "one" ]
}

@test "--domain with a missing AppRole is fatal, never a silent fall back to an ambient token" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  unset DEMO_VAULT_ROLE_ID
  BAO_TOKEN=t run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"DEMO_VAULT_ROLE_ID not in environment"* ]]
  [[ "$output" != *"ran"* ]]
}

@test "an AppRole login failure names the domain" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  LOGIN_FAIL=1 run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"AppRole login failed for domain 'demo'"* ]]
}

@test "an unknown flag is refused rather than treated as a path" {
  run_bao --nope x -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"unknown argument"* ]]
}

@test "a successful run prints no secret value of its own" {
  seed_doc secret app/base '{"ALPHA":"s3cret-value"}'
  BAO_TOKEN=t run_bao --secrets app/base -- sh -c 'true'
  [ "$status" -eq 0 ]
  [[ "$output" != *"s3cret-value"* ]]
  [[ "$stderr" != *"s3cret-value"* ]]
}
