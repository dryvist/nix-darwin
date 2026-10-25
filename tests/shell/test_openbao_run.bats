#!/usr/bin/env bats
#
# openbao-run, driven against a stub OpenBao KV-v2 endpoint — no network.
# Covers the seams that decide whether the wrapper is safe to hand a command:
# whole-document injection (--secrets), left-to-right override so documents
# layer, the two authentication paths (AppRole via --domain, ambient token
# without it), and every way it must fail loudly rather than exec a child with
# nothing exported. The per-domain, per-AppRole login backoff (circuit breaker)
# is covered at the end: refusal timing, credential isolation, no requests while
# open, and only rejected credentials — never network faults — counting.

bats_require_minimum_version 1.5.0 # for `run --separate-stderr`

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

state_path() {
  printf '%s/openbao-run/%s.%s' "$XDG_STATE_HOME" "$1" \
    "$(printf '%s' "$2" | sha256sum | cut -c1-16)"
}

# Stubs get the shebang of the bash actually running the suite, matching the
# convention elsewhere in tests/shell: `/usr/bin/env` is not available
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
  # 404, so a missing document is indistinguishable from the real thing. Every
  # request's URL is appended to $CALLS, so a test can prove nothing was sent.
  # Login outcomes: LOGIN_STATUS=<code> answers that HTTP status (>= 400 exits
  # 22 after printing the status, as `curl -f -w '%{http_code}'` does);
  # LOGIN_CURL_EXIT=<n> is a transport failure (timeout 28, refused 7) that
  # prints 000 and no HTTP status.
  CALLS="$BATS_TEST_TMPDIR/curl-calls"
  : > "$CALLS"
  write_stub "$STUB_DIR/curl" << STUB
url=""
want_code=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -w) want_code=1; shift 2 ;;
    -X|-H|--max-time|-o|--data-binary) shift 2 ;;
    http*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "\$url" >> "$CALLS"

case "\$url" in
  */auth/approle/login)
    if [ -n "\${LOGIN_CURL_EXIT:-}" ]; then
      [ -z "\$want_code" ] || printf '000'
      exit "\$LOGIN_CURL_EXIT"
    fi
    login_status="\${LOGIN_STATUS:-200}"
    if [ "\$login_status" -ge 400 ]; then
      [ -z "\$want_code" ] || printf '%s' "\$login_status"
      exit 22
    fi
    echo '{"auth":{"client_token":"stub-bao-token"}}'
    [ -z "\$want_code" ] || printf '%s' "\$login_status"
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
  # The login backoff state lives under here, never in the real home.
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export BAO_ADDR="https://stub.invalid"
  export DEMO_VAULT_ROLE_ID="stub-role"
  export DEMO_VAULT_SECRET_ID="stub-secret"
  STATE_FILE="$(state_path demo "$DEMO_VAULT_ROLE_ID")"
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
  [[ "$stderr" == *"neither OPENBAO_APPROLE_DEMO_ROLE_ID nor DEMO_VAULT_ROLE_ID in environment"* ]]
  [[ "$output" != *"ran"* ]]
}

@test "--domain reads the rotator's OPENBAO_APPROLE_ names when the legacy ones are gone" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  unset DEMO_VAULT_ROLE_ID DEMO_VAULT_SECRET_ID
  OPENBAO_APPROLE_DEMO_ROLE_ID=stub-role OPENBAO_APPROLE_DEMO_SECRET_ID=stub-secret \
    run_bao --domain demo --secrets app/base -- sh -c 'echo "$ALPHA"'
  [ "$status" -eq 0 ]
  [ "$output" = "one" ]
}

@test "the OPENBAO_APPROLE_ pair is never completed from a legacy secret_id" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  OPENBAO_APPROLE_DEMO_ROLE_ID=stub-role \
    run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"OPENBAO_APPROLE_DEMO_SECRET_ID not in environment"* ]]
}

@test "neither naming of the AppRole pair reaches the exec'd command" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  OPENBAO_APPROLE_DEMO_ROLE_ID=stub-role OPENBAO_APPROLE_DEMO_SECRET_ID=stub-secret \
    run_bao --domain demo --secrets app/base -- sh -c 'env | grep -c -E "^(OPENBAO_APPROLE_DEMO|DEMO_VAULT)_" || true'
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "other domains' AppRole and legacy credentials and tokens do not reach the exec'd command" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  OPENBAO_APPROLE_OTHER_ROLE_ID=other-role OPENBAO_APPROLE_OTHER_SECRET_ID=other-secret \
    OTHER_VAULT_ROLE_ID=legacy-role OTHER_VAULT_SECRET_ID=legacy-secret \
    BAO_TOKEN=ambient-bao VAULT_TOKEN=ambient-vault \
    run_bao --domain demo --secrets app/base -- sh -c 'env | grep -c -E "^(OPENBAO_APPROLE_|[A-Z0-9_]+_VAULT_(ROLE|SECRET)_ID=|BAO_TOKEN=|VAULT_TOKEN=)" || true'
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "credentials are scrubbed under a bash with no compgen builtin, as packaged" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  printf 'enable -n compgen\n' > "$BATS_TEST_TMPDIR/no-compgen"
  BASH_ENV="$BATS_TEST_TMPDIR/no-compgen" \
    OPENBAO_APPROLE_OTHER_ROLE_ID=other-role OPENBAO_APPROLE_OTHER_SECRET_ID=other-secret \
    OTHER_VAULT_ROLE_ID=legacy-role BAO_TOKEN=ambient-bao \
    run_bao --domain demo --secrets app/base -- sh -c 'env | grep -c -E "^(OPENBAO_APPROLE_|[A-Z0-9_]+_VAULT_(ROLE|SECRET)_ID=|BAO_TOKEN=)" || true'
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "credentials are scrubbed in POSIX mode, where export -p prints export NAME" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  POSIXLY_CORRECT=1 \
    OPENBAO_APPROLE_OTHER_ROLE_ID=other-role OPENBAO_APPROLE_OTHER_SECRET_ID=other-secret \
    OTHER_VAULT_ROLE_ID=legacy-role BAO_TOKEN=ambient-bao \
    run_bao --domain demo --secrets app/base -- sh -c 'env | grep -c -E "^(OPENBAO_APPROLE_|[A-Z0-9_]+_VAULT_(ROLE|SECRET)_ID=|BAO_TOKEN=)" || true'
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "a credential name bash cannot unset refuses to exec instead of passing through" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  run --separate-stderr env 'OPENBAO_APPROLE_bad-name=leak' \
    bash -euo pipefail "$SCRIPTS/openbao-run.sh" --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [ "$output" != "ran" ]
  [[ "$stderr" == *"refusing to exec: credential variable OPENBAO_APPROLE_bad-name"* ]]
}

@test "an AppRole login failure names the domain" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  LOGIN_STATUS=403 run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
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

# --- login backoff (per-domain circuit breaker) -----------------------------

# login_as <http-status> — one --domain run whose login answers that status.
login_as() {
  seed_doc secret app/base '{"ALPHA":"one"}'
  LOGIN_STATUS="$1" run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
}

# run_demo — one --domain run against a login that succeeds.
run_demo() {
  seed_doc secret app/base '{"ALPHA":"one"}'
  run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
}

# expire_window — rewrite the state so its backoff window ended long ago,
# keeping the refusal count.
expire_window() {
  local count
  read -r count _ < "$STATE_FILE"
  printf '%s 1\n' "$count" > "$STATE_FILE"
}

@test "a first refused login records one refusal and a 60 second backoff" {
  local before after count next
  before="$(date +%s)"
  login_as 403
  after="$(date +%s)"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"AppRole login failed for domain 'demo'"* ]]
  [[ "$stderr" == *"refusal 1, no login for the next 60 seconds"* ]]
  read -r count next < "$STATE_FILE"
  [ "$count" -eq 1 ]
  [ "$next" -ge $((before + 60)) ]
  [ "$next" -le $((after + 60)) ]
}

@test "inside the backoff window a run exits 75 without sending any request" {
  local count next re
  login_as 403
  read -r count next < "$STATE_FILE"
  : > "$CALLS"
  run_demo
  [ "$status" -eq 75 ]
  [[ "$output" != *"ran"* ]]
  [ ! -s "$CALLS" ]
  re="circuit open for domain 'demo': no login for ([0-9]+) more seconds"
  [[ "$stderr" =~ $re ]]
  [ "${BASH_REMATCH[1]}" -ge 1 ]
  [ "${BASH_REMATCH[1]}" -le 60 ]
  # An open circuit is not a new refusal: the state is untouched.
  read -r count next < "$STATE_FILE"
  [ "$count" -eq 1 ]
}

@test "once the window has passed a login is attempted again" {
  login_as 403
  expire_window
  : > "$CALLS"
  run_demo
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ "$(grep -c '/v1/auth/approle/login$' "$CALLS")" -eq 1 ]
}

@test "a refusal after the window keeps counting from the saved refusals" {
  login_as 403
  expire_window
  login_as 403
  local count
  read -r count _ < "$STATE_FILE"
  [ "$count" -eq 2 ]
  [[ "$stderr" == *"refusal 2, no login for the next 120 seconds"* ]]
}

@test "a successful login deletes the state and says so" {
  login_as 403
  expire_window
  run_demo
  [ "$status" -eq 0 ]
  [ ! -e "$STATE_FILE" ]
  [[ "$stderr" == *"circuit reset for domain 'demo'"* ]]
}

@test "deleting the state file resets the breaker by hand" {
  login_as 403
  rm "$STATE_FILE"
  : > "$CALLS"
  run_demo
  [ "$status" -eq 0 ]
  [ "$(grep -c '/v1/auth/approle/login$' "$CALLS")" -eq 1 ]
}

@test "a success with no state writes none and logs no reset" {
  run_demo
  [ "$status" -eq 0 ]
  [ ! -e "$STATE_FILE" ]
  [[ "$stderr" != *"circuit"* ]]
}

@test "the delay doubles per consecutive refusal and caps at 900 seconds" {
  local expected=(60 120 240 480 900 900 900)
  local i before after count next
  for i in 0 1 2 3 4 5 6; do
    [ ! -e "$STATE_FILE" ] || expire_window
    before="$(date +%s)"
    login_as 401
    after="$(date +%s)"
    read -r count next < "$STATE_FILE"
    [ "$count" -eq $((i + 1)) ]
    [ "$next" -ge $((before + expected[i])) ]
    [ "$next" -le $((after + expected[i])) ]
    [[ "$stderr" == *"no login for the next ${expected[i]} seconds"* ]]
  done
}

@test "a 400, 401 and 403 each count as a refusal" {
  local code
  for code in 400 401 403; do
    rm -f "$STATE_FILE"
    login_as "$code"
    [ -f "$STATE_FILE" ]
    [[ "$stderr" == *"login refused (HTTP $code)"* ]]
  done
}

@test "a timeout, a refused connection or a 5xx creates no state" {
  local code
  for code in 500 502 503 404; do
    login_as "$code"
    [ "$status" -ne 0 ]
    [ ! -e "$STATE_FILE" ]
  done
  for code in 28 7; do
    seed_doc secret app/base '{"ALPHA":"one"}'
    LOGIN_CURL_EXIT="$code" run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"AppRole login failed for domain 'demo'"* ]]
    [ ! -e "$STATE_FILE" ]
  done
}

@test "a network fault leaves existing state exactly as it was" {
  local before
  login_as 403
  expire_window
  before="$(cat "$STATE_FILE")"
  login_as 503
  [ "$(cat "$STATE_FILE")" = "$before" ]
  seed_doc secret app/base '{"ALPHA":"one"}'
  LOGIN_CURL_EXIT=28 run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$(cat "$STATE_FILE")" = "$before" ]
}

@test "the state file is 0600 and its directory 0700, whatever the umask" {
  umask 000
  login_as 403
  [[ "$(ls -ld "$XDG_STATE_HOME/openbao-run")" == drwx------* ]]
  [[ "$(ls -l "$STATE_FILE")" == -rw-------* ]]
}

@test "an existing looser state directory is tightened to 0700" {
  mkdir -p "$XDG_STATE_HOME/openbao-run"
  chmod 0755 "$XDG_STATE_HOME/openbao-run"
  login_as 403
  [[ "$(ls -ld "$XDG_STATE_HOME/openbao-run")" == drwx------* ]]
}

@test "the state holds two counters and no credential" {
  login_as 403
  [[ "$(cat "$STATE_FILE")" =~ ^[0-9]+\ [0-9]+$ ]]
  [[ "$(cat "$STATE_FILE")" != *stub-role* ]]
  [[ "$(cat "$STATE_FILE")" != *stub-secret* ]]
  [[ "$stderr" != *stub-secret* ]]
}

@test "one domain's open circuit never blocks another domain" {
  login_as 403
  export OTHER_VAULT_ROLE_ID="stub-role" OTHER_VAULT_SECRET_ID="stub-secret"
  : > "$CALLS"
  run_bao --domain other --secrets app/base -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ "$(grep -c '/v1/auth/approle/login$' "$CALLS")" -eq 1 ]
}

@test "a refusal for role A does not block role B for the same domain" {
  local role_a role_b state_a
  role_a="role-a-credential"
  role_b="role-b-credential"
  state_a="$(state_path demo "$role_a")"
  seed_doc secret app/base '{"ALPHA":"one"}'

  DEMO_VAULT_ROLE_ID="$role_a" LOGIN_STATUS=403 \
    run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -ne 0 ]
  [ -f "$state_a" ]

  : > "$CALLS"
  DEMO_VAULT_ROLE_ID="$role_b" \
    run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ "$(grep -c '/v1/auth/approle/login$' "$CALLS")" -eq 1 ]
  [ -f "$state_a" ]
}

@test "role A remains blocked on its next run after another role logs in" {
  local role_a role_b state_a
  role_a="role-a-credential"
  role_b="role-b-credential"
  state_a="$(state_path demo "$role_a")"
  seed_doc secret app/base '{"ALPHA":"one"}'

  DEMO_VAULT_ROLE_ID="$role_a" LOGIN_STATUS=403 \
    run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ -f "$state_a" ]

  DEMO_VAULT_ROLE_ID="$role_b" \
    run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -eq 0 ]

  : > "$CALLS"
  DEMO_VAULT_ROLE_ID="$role_a" \
    run_bao --domain demo --secrets app/base -- sh -c 'echo ran'
  [ "$status" -eq 75 ]
  [ ! -s "$CALLS" ]
  [ -f "$state_a" ]
}

@test "the state filename contains no raw role_id" {
  local role_id expected_path
  role_id="role-id-that-must-not-appear"
  expected_path="$(state_path demo "$role_id")"
  seed_doc secret app/base '{"ALPHA":"one"}'

  DEMO_VAULT_ROLE_ID="$role_id" LOGIN_STATUS=403 \
    run_bao --domain demo --secrets app/base -- sh -c 'echo ran'

  [ -f "$expected_path" ]
  [[ "${expected_path##*/}" == demo.???????????????? ]]
  [[ "$expected_path" != *"$role_id"* ]]
}

@test "unreadable state is ignored with a log line, never a lockout" {
  mkdir -p "$XDG_STATE_HOME/openbao-run"
  printf 'garbage\n' > "$STATE_FILE"
  run_demo
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"login backoff state for domain 'demo' is unreadable"* ]]
}

@test "the ambient-token path touches no breaker state" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  BAO_TOKEN=t run_bao --secrets app/base -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ ! -e "$XDG_STATE_HOME" ]
}

@test "--optional with a successful read exports the value" {
  seed_doc secret app/base '{"key":"gateway-value"}'
  run_bao --domain demo --secret GATEWAY_KEY=app/base#key --optional -- sh -c 'echo "$GATEWAY_KEY"'
  [ "$status" -eq 0 ]
  [ "$output" = "gateway-value" ]
  [ -z "$stderr" ]
}

@test "--optional login refusal runs the child, emits one warning, and preserves its exit code" {
  LOGIN_STATUS=403 run_bao --optional --domain demo --secret GATEWAY_KEY=app/base#key -- sh -c 'test -z "${GATEWAY_KEY+x}" && exit 37'
  [ "$status" -eq 37 ]
  [ "$stderr" = "[openbao-run] WARN AppRole login failed; continuing without GATEWAY_KEY" ]
}

@test "--optional with a network login error runs the child with one warning" {
  LOGIN_CURL_EXIT=7 run_bao --domain demo --optional --secret GATEWAY_KEY=app/base#key -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ "$stderr" = "[openbao-run] WARN AppRole login failed; continuing without GATEWAY_KEY" ]
  [ "$(wc -l < "$CALLS" | tr -d ' ')" -eq 1 ]
}

@test "--optional with an open circuit runs the child without sending a request" {
  login_as 403
  : > "$CALLS"
  run_bao --domain demo --secrets app/base --optional -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ ! -s "$CALLS" ]
  [ "$stderr" = "[openbao-run] WARN circuit open; continuing without keys from app/base" ]
}

@test "--optional with a missing field runs the child without the requested variable" {
  seed_doc secret app/base '{"present":"value"}'
  BAO_TOKEN=t run_bao --optional --secret GATEWAY_KEY=app/base#missing -- sh -c 'test -z "${GATEWAY_KEY+x}" && echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ "$stderr" = "[openbao-run] WARN field missing: secret/app/base#missing; continuing without GATEWAY_KEY" ]
}

@test "--optional with a missing path runs the child with one warning" {
  BAO_TOKEN=t run_bao --optional --secret GATEWAY_KEY=app/missing#key -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ "$stderr" = "[openbao-run] WARN read failed: secret/app/missing; continuing without GATEWAY_KEY" ]
}

@test "--optional with no BAO_ADDR runs without making a request" {
  unset BAO_ADDR VAULT_ADDR
  run_bao --domain demo --secret GATEWAY_KEY=app/base#key --optional -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ ! -s "$CALLS" ]
  [ "$stderr" = "[openbao-run] WARN BAO_ADDR unavailable; continuing without GATEWAY_KEY" ]
}

@test "--optional with missing AppRole credentials runs without a request" {
  unset DEMO_VAULT_ROLE_ID DEMO_VAULT_SECRET_ID
  BAO_TOKEN=t run_bao --domain demo --optional --secret GATEWAY_KEY=app/base#key -- sh -c 'echo ran'
  [ "$status" -eq 0 ]
  [ "$output" = "ran" ]
  [ ! -s "$CALLS" ]
  [ "$stderr" = "[openbao-run] WARN AppRole role ID unavailable; continuing without GATEWAY_KEY" ]
}

@test "credentials are scrubbed when --optional degrades before login" {
  unset BAO_ADDR VAULT_ADDR
  OPENBAO_APPROLE_DEMO_ROLE_ID=stub-role OPENBAO_APPROLE_DEMO_SECRET_ID=stub-secret \
    run_bao --domain demo --optional --secret GATEWAY_KEY=app/base#key -- \
      sh -c 'env | grep -c -E "^(OPENBAO_APPROLE_|[A-Z0-9_]+_VAULT_(ROLE|SECRET)_ID=|BAO_TOKEN=|VAULT_TOKEN=)" || true'
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
  [ "$stderr" = "[openbao-run] WARN BAO_ADDR unavailable; continuing without GATEWAY_KEY" ]
}

@test "--optional clears all values after a later read fails" {
  seed_doc secret app/base '{"ALPHA":"one"}'
  BAO_TOKEN=t run_bao --optional --secrets app/base --secret GATEWAY_KEY=app/base#missing -- \
    sh -c 'printf "%s/%s\n" "${ALPHA-unset}" "${GATEWAY_KEY-unset}"'
  [ "$status" -eq 0 ]
  [ "$output" = "unset/unset" ]
  [ "$stderr" = "[openbao-run] WARN field missing: secret/app/base#missing; continuing without keys from app/base, GATEWAY_KEY" ]
}
