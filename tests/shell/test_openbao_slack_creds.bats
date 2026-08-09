#!/usr/bin/env bats
#
# openbao-slack-creds, driven against a stub OpenBao KV-v2 endpoint and a
# stub Slack tooling.tokens.rotate — no network. Covers the three pure-logic
# seams that matter most: the expiry-margin rotation decision, response field
# parsing (`token`/`exp`, not `access_token`/`expires_in`), and the two
# concurrency branches from the single-use refresh token (a CAS-rejected
# write-back, and an `invalid_refresh_token` loss to a sibling process).
# Also exercises the write-back retry/brick path, since losing that write is
# the one failure mode that permanently destroys the credential, and the
# manifest-create/manifest-validate commands (success, rejection, and that
# credential values from apps.manifest.create never reach stdout/stderr),
# and the credentials-persistence write after a successful manifest-create
# (cas:0, correct path, and loud non-zero failure — including the specific
# 403/missing-policy case — rather than silently losing an unrecoverable
# secret).

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
  MANIFEST_CALLS="$BATS_TEST_TMPDIR/manifest-calls"
  CREDS_WRITE_URLS="$BATS_TEST_TMPDIR/creds-write-urls"
  CREDS_WRITE_BODIES="$BATS_TEST_TMPDIR/creds-write-bodies"
  CHANNELS_FILE="$BATS_TEST_TMPDIR/channels.json"
  MEMBERS_FILE="$BATS_TEST_TMPDIR/members.json"
  CHANNEL_CALLS="$BATS_TEST_TMPDIR/channel-calls"
  CHANNEL_POST_BODIES="$BATS_TEST_TMPDIR/channel-post-bodies"
  : > "$ROTATE_CALLS"
  : > "$WRITE_ATTEMPTS"
  : > "$MANIFEST_CALLS"
  : > "$CREDS_WRITE_URLS"
  : > "$CREDS_WRITE_BODIES"
  : > "$CHANNEL_CALLS"
  : > "$CHANNEL_POST_BODIES"
  echo '[]' > "$CHANNELS_FILE"
  echo '[]' > "$MEMBERS_FILE"

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
    role_id=\$(echo "\$data" | jq -r '.role_id')
    if [ -n "\${SLACK_OPS_LOGIN_FAIL:-}" ] && [ "\$role_id" = "\$OPENBAO_APPROLE_SLACK_OPS_ROLE_ID" ]; then
      exit 1
    fi
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
  https://slack.com/api/apps.manifest.create)
    echo "1" >> "$MANIFEST_CALLS"
    if [ "\${MANIFEST_MODE:-ok}" = "ok" ]; then
      echo '{"ok":true,"app_id":"A123","oauth_authorize_url":"https://api.slack.com/apps/A123/install-on-team","credentials":{"client_id":"999.888","client_secret":"SUPERSECRETVALUE","verification_token":"SUPERVERIFYTOKEN","signing_secret":"SUPERSIGNSECRET"}}'
    else
      echo '{"ok":false,"errors":[{"message":"invalid_manifest"}]}'
    fi
    ;;
  https://slack.com/api/apps.manifest.validate)
    echo "1" >> "$MANIFEST_CALLS"
    if [ "\${MANIFEST_MODE:-ok}" = "ok" ]; then
      echo '{"ok":true}'
    else
      echo '{"ok":false,"errors":[{"message":"invalid_manifest"}]}'
    fi
    ;;
  */secrets-external/data/platform/slack-app-*)
    printf '%s\n' "\$url" >> "$CREDS_WRITE_URLS"
    printf '%s\n' "\$data" >> "$CREDS_WRITE_BODIES"
    case "\${CREDS_WRITE_MODE:-ok}" in
      ok)  echo -n "200" ;;
      403) echo -n "403" ;;
      *)   echo -n "500" ;;
    esac
    ;;
  */secrets-external/data/platform/slack-ops)
    jq -cn '{data: {data: {bot_token: "stub-bot-token"}}}'
    ;;
  https://slack.com/api/conversations.list*)
    # Paginated over \$CHANNELS_FILE; CHANNEL_PAGE_SIZE controls page size
    # (default large enough for one page) so pagination tests are explicit.
    page_size=\${CHANNEL_PAGE_SIZE:-1000}
    cursor=\$(printf '%s' "\$url" | sed -n 's/.*[?&]cursor=\([^&]*\).*/\1/p')
    offset=\${cursor:-0}
    all=\$(cat "$CHANNELS_FILE")
    excl=\$(printf '%s' "\$url" | sed -n 's/.*[?&]exclude_archived=\([^&]*\).*/\1/p')
    if [ "\$excl" = "true" ]; then
      all=\$(jq -c '[.[] | select(.is_archived != true)]' <<<"\$all")
    fi
    total=\$(jq 'length' <<<"\$all")
    end=\$((offset + page_size))
    [ "\$end" -gt "\$total" ] && end=\$total
    chans=\$(jq -c ".[\$offset:\$end]" <<<"\$all")
    if [ "\$end" -lt "\$total" ]; then
      jq -cn --argjson c "\$chans" --arg nc "\$end" '{ok:true, channels:\$c, response_metadata:{next_cursor:\$nc}}'
    else
      jq -cn --argjson c "\$chans" '{ok:true, channels:\$c, response_metadata:{next_cursor:""}}'
    fi
    ;;
  https://slack.com/api/conversations.members*)
    page_size=\${CHANNEL_PAGE_SIZE:-1000}
    cursor=\$(printf '%s' "\$url" | sed -n 's/.*[?&]cursor=\([^&]*\).*/\1/p')
    offset=\${cursor:-0}
    all=\$(cat "$MEMBERS_FILE")
    total=\$(jq 'length' <<<"\$all")
    end=\$((offset + page_size))
    [ "\$end" -gt "\$total" ] && end=\$total
    mem=\$(jq -c ".[\$offset:\$end]" <<<"\$all")
    if [ "\$end" -lt "\$total" ]; then
      jq -cn --argjson m "\$mem" --arg nc "\$end" '{ok:true, members:\$m, response_metadata:{next_cursor:\$nc}}'
    else
      jq -cn --argjson m "\$mem" '{ok:true, members:\$m, response_metadata:{next_cursor:""}}'
    fi
    ;;
  https://slack.com/api/conversations.info*)
    chan_id=\$(printf '%s' "\$url" | sed -n 's/.*channel=\([^&]*\).*/\1/p')
    name=\$(jq -r --arg id "\$chan_id" '.[] | select(.id==\$id) | .name' "$CHANNELS_FILE")
    jq -cn --arg n "\${name:-unknown}" '{ok:true, channel:{name:\$n}}'
    ;;
  https://slack.com/api/conversations.create)
    echo "1" >> "$CHANNEL_CALLS"
    printf '%s\n' "\$data" >> "$CHANNEL_POST_BODIES"
    if [ -n "\${FORCE_MISSING_SCOPE:-}" ]; then
      echo '{"ok":false,"error":"missing_scope","needed":"groups:write","provided":"channels:write,chat:write,channels:manage"}'
    else
      name=\$(echo "\$data" | jq -r '.name')
      jq -cn --arg n "\$name" '{ok:true, channel:{id:("C_NEW_" + \$n), name:\$n}}'
    fi
    ;;
  https://slack.com/api/conversations.rename | https://slack.com/api/conversations.setTopic | https://slack.com/api/conversations.setPurpose | https://slack.com/api/conversations.archive)
    echo "1" >> "$CHANNEL_CALLS"
    printf '%s\n' "\$data" >> "$CHANNEL_POST_BODIES"
    echo '{"ok":true}'
    ;;
  https://slack.com/api/conversations.invite)
    echo "1" >> "$CHANNEL_CALLS"
    printf '%s\n' "\$data" >> "$CHANNEL_POST_BODIES"
    if [ "\${INVITE_MODE:-ok}" = "fail" ]; then
      echo '{"ok":false,"error":"already_in_channel"}'
    else
      echo '{"ok":true}'
    fi
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
  export OPENBAO_APPROLE_SLACK_OPS_ROLE_ID="stub-slack-ops-role"
  export OPENBAO_APPROLE_SLACK_OPS_SECRET_ID="stub-slack-ops-secret"
}

# Seeds $CHANNELS_FILE from "id:name[:is_archived]" specs, e.g.
# "C1:general" or "C2:old-project:true".
seed_channels() {
  local json="[]" spec id name archived
  for spec in "$@"; do
    IFS=: read -r id name archived <<<"$spec"
    json="$(jq -c --arg id "$id" --arg n "$name" --argjson a "${archived:-false}" \
      '. + [{id: $id, name: $n, is_archived: $a}]' <<<"$json")"
  done
  printf '%s' "$json" > "$CHANNELS_FILE"
}

seed_members() {  # $@ = user ids
  printf '%s\n' "$@" | jq -R . | jq -cs . > "$MEMBERS_FILE"
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

@test "manifest-create prints app_id and oauth_authorize_url to stdout and never leaks credential values" {
  seed_kv "$(far_future)" 200
  echo '{"display_information":{"name":"test"}}' > "$BATS_TEST_TMPDIR/manifest.json"
  MANIFEST_MODE=ok run_creds manifest-create "$BATS_TEST_TMPDIR/manifest.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"app_id=A123"* ]]
  [[ "$output" == *"oauth_authorize_url=https://api.slack.com/apps/A123/install-on-team"* ]]
  [[ "$output" != *"SECRETVALUE"* ]]
  [[ "$output" != *"SIGNSECRET"* ]]
  [[ "$stderr" != *"SECRETVALUE"* ]]
}

@test "manifest-create fails loudly when Slack rejects the manifest" {
  seed_kv "$(far_future)" 200
  echo '{"display_information":{"name":"test"}}' > "$BATS_TEST_TMPDIR/manifest.json"
  MANIFEST_MODE=fail run_creds manifest-create "$BATS_TEST_TMPDIR/manifest.json"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"invalid_manifest"* ]]
}

@test "manifest-create dies when the manifest file does not exist" {
  seed_kv "$(far_future)" 200
  run_creds manifest-create "$BATS_TEST_TMPDIR/missing.json"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"not found"* ]]
}

@test "manifest-validate succeeds against a valid manifest, consuming no rotation" {
  seed_kv "$(far_future)" 200
  echo '{"display_information":{"name":"test"}}' > "$BATS_TEST_TMPDIR/manifest.json"
  MANIFEST_MODE=ok run_creds manifest-validate "$BATS_TEST_TMPDIR/manifest.json"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"manifest valid"* ]]
  [ ! -s "$ROTATE_CALLS" ]
}

@test "manifest-validate reports errors for an invalid manifest" {
  seed_kv "$(far_future)" 200
  echo '{"bad":true}' > "$BATS_TEST_TMPDIR/manifest.json"
  MANIFEST_MODE=fail run_creds manifest-validate "$BATS_TEST_TMPDIR/manifest.json"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"invalid_manifest"* ]]
}

@test "manifest-create persists app credentials with cas:0 at the lowercased app_id path, and never leaks secret values" {
  seed_kv "$(far_future)" 200
  echo '{"display_information":{"name":"Test App"}}' > "$BATS_TEST_TMPDIR/manifest.json"
  MANIFEST_MODE=ok CREDS_WRITE_MODE=ok run_creds manifest-create "$BATS_TEST_TMPDIR/manifest.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"app_id=A123"* ]]
  [[ "$output" != *"SUPERSECRETVALUE"* ]]
  [[ "$output" != *"SUPERSIGNSECRET"* ]]
  [[ "$output" != *"SUPERVERIFYTOKEN"* ]]
  [[ "$stderr" != *"SUPERSECRETVALUE"* ]]
  [[ "$stderr" != *"SUPERSIGNSECRET"* ]]
  [[ "$stderr" != *"SUPERVERIFYTOKEN"* ]]
  grep -q "secrets-external/data/platform/slack-app-a123" "$CREDS_WRITE_URLS"
  [ "$(jq -r '.options.cas' "$CREDS_WRITE_BODIES")" = "0" ]
  [ "$(jq -r '.data.client_secret' "$CREDS_WRITE_BODIES")" = "SUPERSECRETVALUE" ]
  [ "$(jq -r '.data.app_name' "$CREDS_WRITE_BODIES")" = "Test App" ]
}

@test "a 403 on the credentials write names the missing OpenBao capability and fails loudly" {
  seed_kv "$(far_future)" 200
  echo '{"display_information":{"name":"Test App"}}' > "$BATS_TEST_TMPDIR/manifest.json"
  MANIFEST_MODE=ok CREDS_WRITE_MODE=403 run_creds manifest-create "$BATS_TEST_TMPDIR/manifest.json"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"403"* ]]
  [[ "$stderr" == *"slack-admin policy lacks 'create'"* ]]
  [[ "$stderr" == *"UNRECOVERABLE"* ]]
  [[ "$stderr" == *"A123"* ]]
}

@test "a generic credentials-write failure reports the app as created but its credentials unrecoverable" {
  seed_kv "$(far_future)" 200
  echo '{"display_information":{"name":"Test App"}}' > "$BATS_TEST_TMPDIR/manifest.json"
  MANIFEST_MODE=ok CREDS_WRITE_MODE=fail run_creds manifest-create "$BATS_TEST_TMPDIR/manifest.json"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"UNRECOVERABLE"* ]]
  [[ "$stderr" == *"500"* ]]
}

# --- channel management --------------------------------------------------
# Uses the bot token (secrets-external/data/platform/slack-ops), not the app-config token
# above — these tests never touch $KV_STATE.

@test "a missing slack-ops AppRole credential dies naming the missing env vars, not a generic auth error" {
  unset OPENBAO_APPROLE_SLACK_OPS_ROLE_ID
  seed_channels "C1:general"
  run_creds channel list
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"OPENBAO_APPROLE_SLACK_OPS_ROLE_ID"* ]]
}

@test "a slack-ops AppRole login failure names the AppRole, not a confusing generic auth error" {
  seed_channels "C1:general"
  SLACK_OPS_LOGIN_FAIL=1 run_creds channel list
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"SLACK_OPS"* ]]
  [[ "$stderr" == *"slack-ops AppRole exists in OpenBao"* ]]
}

@test "channel list prints id, name and archived flag tab-separated, excluding archived by default" {
  seed_channels "C1:general" "C2:old-project:true"
  run_creds channel list
  [ "$status" -eq 0 ]
  [[ "$output" == *"C1"$'\t'"general"$'\t'"false"* ]]
  [[ "$output" != *"C2"* ]]
}

@test "channel list --include-archived also prints archived channels" {
  seed_channels "C1:general" "C2:old-project:true"
  run_creds channel list --include-archived
  [ "$status" -eq 0 ]
  [[ "$output" == *"C1"* ]]
  [[ "$output" == *"C2"$'\t'"old-project"$'\t'"true"* ]]
}

@test "a channel name resolves to its id on a single page" {
  seed_channels "C1:general"
  run_creds channel topic general "new topic"
  [ "$status" -eq 0 ]
  grep -q '"channel":"C1"' "$CHANNEL_POST_BODIES"
  grep -q '"topic":"new topic"' "$CHANNEL_POST_BODIES"
}

@test "a channel name matching only on a second page still resolves, proving pagination is followed" {
  seed_channels "C1:alpha" "C2:beta" "C3:target"
  CHANNEL_PAGE_SIZE=1 run_creds channel topic target "hi"
  [ "$status" -eq 0 ]
  grep -q '"channel":"C3"' "$CHANNEL_POST_BODIES"
}

@test "an ambiguous channel name fails rather than guessing" {
  seed_channels "C1:dup" "C2:dup"
  run_creds channel topic dup "hi"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"ambiguous"* ]]
}

@test "a channel name matching nothing fails" {
  seed_channels "C1:general"
  run_creds channel topic ghost "hi"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"no channel named"* ]]
}

@test "channel create prints the new channel id to stdout" {
  run_creds channel create newchan
  [ "$status" -eq 0 ]
  [ "$output" = "C_NEW_newchan" ]
}

@test "channel create --private succeeds and prints the new channel id to stdout" {
  run_creds channel create secretchan --private
  [ "$status" -eq 0 ]
  [ "$output" = "C_NEW_secretchan" ]
  grep -q '"is_private":true' "$CHANNEL_POST_BODIES"
}

@test "a missing_scope response fails with the specific message naming the missing scope (defensive branch)" {
  FORCE_MISSING_SCOPE=1 run_creds channel create anychan
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"missing_scope"* ]]
  [[ "$stderr" == *"groups:write"* ]]
}

@test "channel rename accepts a literal channel ID directly, with no name-resolution lookup" {
  run_creds channel rename C999 new-name
  [ "$status" -eq 0 ]
  grep -q '"channel":"C999"' "$CHANNEL_POST_BODIES"
  grep -q '"name":"new-name"' "$CHANNEL_POST_BODIES"
}

@test "channel invite passes multiple user ids as a comma-separated list" {
  seed_channels "C1:general"
  run_creds channel invite general U1 U2 U3
  [ "$status" -eq 0 ]
  grep -q '"users":"U1,U2,U3"' "$CHANNEL_POST_BODIES"
}

@test "a Slack .ok:false response fails loudly with Slack's error string, never silently" {
  seed_channels "C1:general"
  INVITE_MODE=fail run_creds channel invite general U1
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"already_in_channel"* ]]
}

@test "channel archive logs the id and resolved name to stderr before archiving" {
  seed_channels "C1:general"
  run_creds channel archive general
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"archiving channel C1 (general)"* ]]
  [ "$(wc -l < "$CHANNEL_CALLS")" -eq 1 ]
}

@test "channel members lists user ids, following pagination across pages" {
  seed_channels "C1:general"
  seed_members "U1" "U2" "U3"
  CHANNEL_PAGE_SIZE=1 run_creds channel members general
  [ "$status" -eq 0 ]
  [[ "$output" == *"U1"* ]]
  [[ "$output" == *"U2"* ]]
  [[ "$output" == *"U3"* ]]
}
