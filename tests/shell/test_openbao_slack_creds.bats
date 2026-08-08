#!/usr/bin/env bats
#
# openbao-slack-creds, driven against a stub OpenBao KV-v2 endpoint and a
# stub Slack tooling.tokens.rotate — no network. Covers the three pure-logic
# seams that matter most: the expiry-margin rotation decision, response field
# parsing (`token`/`exp`, not `access_token`/`expires_in`), and the two
# concurrency branches from the single-use refresh token (a CAS-rejected
# write-back, and an `invalid_refresh_token` loss to a sibling process).
# Also exercises the write-back retry/brick path, since losing that write is
# the one failure mode that permanently destroys the credential.

bats_require_minimum_version 1.5.0 # for `run --separate-stderr`

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

# Stubs get the shebang of the bash actually running the suite, matching the
# convention in test_cluster_maintenance_window.bats: `/usr/bin/env` is not
# available in the Nix build sandbox these tests run in, and a stub that
# fails to exec would silently answer every call the same way.
write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB_DIR"
  KV_STATE="$BATS_TEST_TMPDIR/kv-state.json"
  ROTATE_CALLS="$BATS_TEST_TMPDIR/rotate-calls"
  WRITE_ATTEMPTS="$BATS_TEST_TMPDIR/write-attempts"
  : > "$ROTATE_CALLS"
  : > "$WRITE_ATTEMPTS"

  # This repo's OpenBao scripts target BSD `/bin/date` (macOS-only, by
  # design — these scripts only ever run on the user's Mac). That binary
  # doesn't exist in the Linux `nix flake check` sandbox these tests run in,
  # so translate the handful of forms the script actually calls onto GNU
  # `date`, which does.
  write_stub "$STUB_DIR/date" << 'STUB'
if [ "$1" = "-j" ] && [ "$2" = "-u" ] && [ "$3" = "-f" ]; then
  val="$5"; shift 5
  exec date -u -d "$val" "$@"
elif [ "$1" = "-u" ] && [ "$2" = "-r" ]; then
  epoch="$3"; shift 3
  exec date -u -d "@$epoch" "$@"
else
  exec date "$@"
fi
STUB

  # Stub OpenBao + Slack. Distinguishes by URL and method, and actually
  # maintains KV_STATE across calls so a rotation's write-back is visible to
  # the next read — the tests below depend on that being real, not recorded.
  write_stub "$STUB_DIR/curl" << STUB
method="GET"; data=""; url=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -X) method="\$2"; shift 2 ;;
    -d|--data-urlencode) data="\$2"; shift 2 ;;
    -H|--max-time|-o) shift 2 ;;
    -w) shift 2 ;;
    -s|-f|-sf) shift ;;
    http*) url="\$1"; shift ;;
    *) shift ;;
  esac
done

case "\$url" in
  */auth/approle/login)
    echo '{"auth":{"client_token":"stub-bao-token"}}'
    ;;
  */secrets-external/data/platform/slack-admin)
    if [ "\$method" = "POST" ]; then
      echo "1" >> "$WRITE_ATTEMPTS"
      attempt=\$(wc -l < "$WRITE_ATTEMPTS")
      if [ -n "\${WRITE_FAIL_COUNT:-}" ] && [ "\$attempt" -le "\$WRITE_FAIL_COUNT" ]; then
        echo -n "500"
        exit 0
      fi
      cas=\$(echo "\$data" | jq -r '.options.cas')
      cur_ver=\$(jq -r '.version' "$KV_STATE")
      if [ -n "\${WRITE_SIMULATE_RACE:-}" ] && [ ! -f "$BATS_TEST_TMPDIR/race-done" ]; then
        touch "$BATS_TEST_TMPDIR/race-done"
        jq -n --argjson v "\$((cur_ver + 1))" \
          '{version: \$v, data: {app_config_token: "concurrent-token", app_config_refresh_token: "concurrent-refresh", rotated_at: "2026-01-01T00:00:00Z", expires_at: "2099-01-01T00:00:00Z"}}' \
          > "$KV_STATE"
        cur_ver=\$((cur_ver + 1))
      fi
      if [ "\$cas" != "\$cur_ver" ]; then
        echo -n "400"
        exit 0
      fi
      new_data=\$(echo "\$data" | jq '.data')
      jq -n --argjson v "\$((cur_ver + 1))" --argjson d "\$new_data" '{version: \$v, data: \$d}' > "$KV_STATE"
      echo -n "200"
    else
      jq -c '{data: {data: .data, metadata: {version: .version}}}' "$KV_STATE"
    fi
    ;;
  https://slack.com/api/tooling.tokens.rotate)
    echo "refresh_token=\$data" >> "$ROTATE_CALLS"
    exp=\$(( \$(date -u +%s) + 43200 ))
    case "\${SLACK_ROTATE_MODE:-ok}" in
      ok)
        echo "{\\"ok\\":true,\\"token\\":\\"new-token\\",\\"refresh_token\\":\\"new-refresh\\",\\"exp\\":\$exp}"
        ;;
      invalid)
        echo '{"ok":false,"error":"invalid_refresh_token"}'
        ;;
      invalid_but_winner)
        cur_ver=\$(jq -r '.version' "$KV_STATE")
        jq -n --argjson v "\$((cur_ver + 1))" \
          '{version: \$v, data: {app_config_token: "sibling-token", app_config_refresh_token: "sibling-refresh", rotated_at: "2026-01-01T00:00:00Z", expires_at: "2099-01-01T00:00:00Z"}}' \
          > "$KV_STATE"
        echo '{"ok":false,"error":"invalid_refresh_token"}'
        ;;
    esac
    ;;
  *)
    echo '{}'
    ;;
esac
STUB

  export OPENBAO_SLACK_CREDS_CURL_BIN="$STUB_DIR/curl"
  export OPENBAO_SLACK_CREDS_DATE_BIN="$STUB_DIR/date"
  export OPENBAO_SLACK_CREDS_MAX_WRITE_RETRIES=3
  export OPENBAO_SLACK_CREDS_RETRY_BACKOFF_SECONDS=0
  export BAO_ADDR="https://stub.invalid"
  export OPENBAO_APPROLE_SLACK_ADMIN_ROLE_ID="stub-role"
  export OPENBAO_APPROLE_SLACK_ADMIN_SECRET_ID="stub-secret"
}

seed_kv() {  # $1 expires_at (or "" for none), $2 safety margin seconds
  jq -n --arg ea "$1" \
    '{version: 1, data: {app_config_token: "stored-token", app_config_refresh_token: "stored-refresh", rotated_at: "2026-01-01T00:00:00Z", expires_at: (if $ea == "" then null else $ea end)}}' \
    > "$KV_STATE"
  export OPENBAO_SLACK_CREDS_SAFETY_MARGIN="${2:-7200}"
}

far_future() { date -u -d "+100000 seconds" +%Y-%m-%dT%H:%M:%SZ; }
near_expiry() { date -u -d "+50 seconds" +%Y-%m-%dT%H:%M:%SZ; }

# --separate-stderr keeps $output pure stdout (what a real command
# substitution would capture) and puts the warn()/die() log lines in
# $stderr instead — needed because plain `run` merges both streams, which
# would make "nothing else on stdout" unverifiable.
run_creds() { run --separate-stderr bash -euo pipefail "$SCRIPTS/openbao-slack-creds.sh" "$@"; }

@test "the stub actually executes — a dead stub would fake every answer" {
  run "$STUB_DIR/curl" -sf -X POST "https://stub.invalid/v1/auth/approle/login"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stub-bao-token"* ]]
}

@test "a token comfortably inside its safety margin is returned without rotating" {
  seed_kv "$(far_future)" 200
  run_creds token
  [ "$status" -eq 0 ]
  [ "$output" = "stored-token" ]
  [ ! -s "$ROTATE_CALLS" ]
}

@test "a token within the safety margin rotates and returns the fresh token" {
  seed_kv "$(near_expiry)" 200
  SLACK_ROTATE_MODE=ok run_creds token
  [ "$status" -eq 0 ]
  [ "$output" = "new-token" ]
  grep -q "refresh_token=stored-refresh" "$ROTATE_CALLS"
  [ "$(jq -r '.version' "$KV_STATE")" = "2" ]
  [ "$(jq -r '.data.app_config_token' "$KV_STATE")" = "new-token" ]
}

@test "an absent expires_at is treated as due for rotation, not as fresh" {
  seed_kv "" 200
  SLACK_ROTATE_MODE=ok run_creds token
  [ "$status" -eq 0 ]
  [ "$output" = "new-token" ]
}

@test "rotate forces a fresh token even when far from expiry, and never prints to stdout" {
  seed_kv "$(far_future)" 200
  SLACK_ROTATE_MODE=ok run_creds rotate
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -r '.version' "$KV_STATE")" = "2" ]
}

@test "rotate's human summary goes to stderr and names the new expiry" {
  seed_kv "$(far_future)" 200
  SLACK_ROTATE_MODE=ok bash -euo pipefail "$SCRIPTS/openbao-slack-creds.sh" rotate 1>/dev/null 2> "$BATS_TEST_TMPDIR/err"
  grep -q "rotation complete" "$BATS_TEST_TMPDIR/err"
  grep -q "new token expires" "$BATS_TEST_TMPDIR/err"
}

@test "a write-back CAS rejection adopts the concurrent writer's result, not a retry of its own" {
  seed_kv "$(near_expiry)" 200
  SLACK_ROTATE_MODE=ok WRITE_SIMULATE_RACE=1 run_creds token
  [ "$status" -eq 0 ]
  [ "$output" = "concurrent-token" ]
  [ "$(wc -l < "$WRITE_ATTEMPTS")" -eq 1 ]
}

@test "an invalid refresh token with no newer credential fails loudly, naming manual regeneration" {
  seed_kv "$(near_expiry)" 200
  SLACK_ROTATE_MODE=invalid run_creds rotate
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"MANUAL REGENERATION"* ]]
  [[ "$stderr" == *"api.slack.com"* ]]
  [ "$(jq -r '.version' "$KV_STATE")" = "1" ]
}

@test "an invalid refresh token that lost a race adopts the sibling's fresh pair instead of failing" {
  seed_kv "$(near_expiry)" 200
  SLACK_ROTATE_MODE=invalid_but_winner run_creds token
  [ "$status" -eq 0 ]
  [ "$output" = "sibling-token" ]
}

@test "write-back is retried on a transient failure and eventually succeeds" {
  seed_kv "$(near_expiry)" 200
  SLACK_ROTATE_MODE=ok WRITE_FAIL_COUNT=2 run_creds rotate
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"retrying"* ]]
  [ "$(wc -l < "$WRITE_ATTEMPTS")" -eq 3 ]
  [ "$(jq -r '.version' "$KV_STATE")" = "2" ]
}

@test "write-back exhausts its retries and reports the credential as bricked, never silently" {
  seed_kv "$(near_expiry)" 200
  SLACK_ROTATE_MODE=ok WRITE_FAIL_COUNT=99 run_creds rotate
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"BRICKED"* ]]
  [[ "$stderr" == *"manual regeneration"* ]]
  [ "$(jq -r '.version' "$KV_STATE")" = "1" ]
}
