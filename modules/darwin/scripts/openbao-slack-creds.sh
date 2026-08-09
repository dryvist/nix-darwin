#!/usr/bin/env bash
#
# Slack app configuration token provider backed by OpenBao KV-v2, the Slack
# analogue of openbao-github-creds.sh. Manages the token pair Slack's
# tooling.tokens.rotate endpoint issues:
#
#   app_config_token          xoxe.xoxp-…  short-lived (~12h) bearer token
#   app_config_refresh_token  xoxe-…       SINGLE USE — rotating consumes it
#
# stored at secrets-external/data/platform/slack-admin alongside rotated_at
# and expires_at (both ISO8601 UTC; expires_at is derived from the rotate
# response's `exp` epoch).
#
# SUBCOMMANDS: token, rotate, manifest-create <path>, manifest-validate
# <path> (apps.manifest.create / .validate against a local manifest JSON
# file), channel {list|create|rename|topic|purpose|invite|archive|members}
# (conversations.* channel lifecycle ops), --self-check. manifest-create/
# validate obtain their bearer token through the exact same
# get_valid_token() path as `token`. manifest-create also persists the
# one-time app credentials Slack returns — see persist_app_credentials
# below.
#
# SECRET-ZERO is AMBIENT, identical in shape to openbao-github-creds.sh, and
# spans TWO separate identities for TWO separate credentials — never mix
# them up:
#
#   token/rotate/manifest-*  app-configuration token (apps.manifest.* only)
#                            KV-v2 at secrets-external/data/platform/slack-admin
#                            AppRole: OPENBAO_APPROLE_SLACK_ADMIN_ROLE_ID /
#                            OPENBAO_APPROLE_SLACK_ADMIN_SECRET_ID
#   channel *                bot token (conversations.*/chat.* scopes)
#                            KV-v2 at secrets-external/data/platform/slack-ops,
#                            key `bot_token`. This app has token rotation
#                            disabled, so the token does not expire — there
#                            is no rotation logic for it, unlike slack-admin.
#                            AppRole: OPENBAO_APPROLE_SLACK_OPS_ROLE_ID /
#                            OPENBAO_APPROLE_SLACK_OPS_SECRET_ID
#
# BAO_ADDR (or legacy VAULT_ADDR) is shared by both. Injected by running
# under `doppler run`. AppRole login (bao_login / bao_login_slack_ops) is the
# ONLY credential path in this file — there is no break-glass, no
# root-token fallback, and no operator-supplied token; every code path that
# needs a token gets it from get_valid_token() or get_bot_token(), which
# always go through one of those two logins.
#
# CONCURRENCY: the refresh token is single-use, which is Slack's own mutex —
# two rotations racing on the same refresh token can only ever produce one
# winner, so no client-side lock is taken before calling Slack. Two things
# still need guarding explicitly:
#
#   1. The loser of that race must not treat "Slack rejected my refresh
#      token" as failure without first checking whether a sibling process
#      already won and published a newer pair — see do_rotate below.
#   2. The write-back to OpenBao after a WON rotation must not silently
#      lose the new pair: Slack has already burned the old refresh token by
#      the time we know whether the write succeeded, so losing the write
#      bricks the credential. CAS-protects the write, then retries it.
#
# ponytail: no on-disk cache and no on-disk token, same rule as
# openbao-github-creds.sh — never a temp file, never a cache directory.
#
# TEST SEAMS (all optional, default to the real binaries/values):
#   OPENBAO_SLACK_CREDS_CURL_BIN / _DATE_BIN   swap curl / BSD `/bin/date`
#   OPENBAO_SLACK_CREDS_SAFETY_MARGIN          rotation trigger window (s)
#   OPENBAO_SLACK_CREDS_MAX_WRITE_RETRIES / _RETRY_BACKOFF_SECONDS
#     bound the write-back retry loop so tests don't wait on real backoff.
#
# `pkgs.writeShellApplication` wraps this in `set -euo pipefail` and lints
# it, so this file omits its own set line.

# Without this, a die() (exit 1) inside a command substitution nested two
# levels deep — e.g. tok="$(get_bot_token)" where get_bot_token itself does
# bao_tok="$(bao_login_slack_ops)" — gets silently swallowed: `set -e` does
# not propagate into `$()` subshells by default, only the outermost one.
shopt -s inherit_errexit

prefix="[openbao-slack-creds]"
die() { echo "$prefix ERROR $*" >&2; exit 1; }
warn() { echo "$prefix WARN $*" >&2; }

kv_path="secrets-external/data/platform/slack-admin"

bao_addr="${BAO_ADDR:-${VAULT_ADDR:-}}"
curl_bin="${OPENBAO_SLACK_CREDS_CURL_BIN:-curl}"
date_bin="${OPENBAO_SLACK_CREDS_DATE_BIN:-/bin/date}" # BSD date (macOS-only, see epoch_of)
safety_margin="${OPENBAO_SLACK_CREDS_SAFETY_MARGIN:-7200}" # 2h, override for tests/tuning
max_write_retries="${OPENBAO_SLACK_CREDS_MAX_WRITE_RETRIES:-5}"
write_retry_backoff="${OPENBAO_SLACK_CREDS_RETRY_BACKOFF_SECONDS:-1}"

require_env() {
  [ -n "${bao_addr}" ] || die "BAO_ADDR not set — run under 'doppler run'"
}

# AppRole login for the slack-admin identity; prints the client_token.
bao_login() {
  local role_id secret_id resp token
  role_id="${OPENBAO_APPROLE_SLACK_ADMIN_ROLE_ID:-}"
  secret_id="${OPENBAO_APPROLE_SLACK_ADMIN_SECRET_ID:-}"
  [ -n "${role_id}" ] && [ -n "${secret_id}" ] || \
    die "OPENBAO_APPROLE_SLACK_ADMIN_ROLE_ID / OPENBAO_APPROLE_SLACK_ADMIN_SECRET_ID not in environment — run under 'doppler run'"
  resp="$("${curl_bin}" -sf --max-time 10 -X POST \
    -d "{\"role_id\":\"${role_id}\",\"secret_id\":\"${secret_id}\"}" \
    "${bao_addr}/v1/auth/approle/login")" || die "AppRole login (SLACK_ADMIN) failed"
  token="$(jq -r '.auth.client_token // empty' <<<"${resp}")"
  [ -n "${token}" ] || die "AppRole login (SLACK_ADMIN) returned no client_token"
  printf '%s' "${token}"
}

# Prints the raw Vault response envelope for the KV-v2 entry (.data.data.* for
# the fields, .data.metadata.version for CAS).
kv_read() {
  local bao_tok="$1"
  "${curl_bin}" -sf --max-time 10 -H "X-Vault-Token: ${bao_tok}" "${bao_addr}/v1/${kv_path}"
}

# CAS write-back. Prints the HTTP status code; 200 = written, 400 = a
# concurrent writer beat us to this version.
kv_write_cas() {
  local bao_tok="$1" ver="$2" tok="$3" refresh="$4" rotated_at="$5" expires_at="$6" body
  body="$(jq -cn --argjson v "${ver}" --arg t "${tok}" --arg r "${refresh}" \
    --arg ra "${rotated_at}" --arg ea "${expires_at}" \
    '{options: {cas: $v}, data: {app_config_token: $t, app_config_refresh_token: $r, rotated_at: $ra, expires_at: $ea}}')"
  "${curl_bin}" -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST \
    -H "X-Vault-Token: ${bao_tok}" -d "${body}" "${bao_addr}/v1/${kv_path}"
}

# ISO8601 UTC -> epoch seconds, BSD date (macOS-only, same as openbao-aws-creds.sh).
epoch_of() {
  "${date_bin}" -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null
}

# True if $1 (an expires_at, possibly empty) is within the safety margin of
# expiry — including "no expiry on record", which rotates rather than risks
# handing out a token that might already be dead.
needs_rotation() {
  local expires_at="$1" exp_epoch now_epoch
  [ -n "${expires_at}" ] || return 0
  exp_epoch="$(epoch_of "${expires_at}")" || return 0
  now_epoch="$("${date_bin}" -u +%s)"
  [ "$((exp_epoch - now_epoch))" -le "${safety_margin}" ]
}

# POST to Slack's rotate endpoint. No Authorization header — the refresh
# token in the body IS the credential. Slack answers 200 with {"ok":false,…}
# on a rejected rotation, so -f alone would not catch a dead refresh token;
# callers check .ok themselves.
slack_rotate() {
  "${curl_bin}" -sf --max-time 15 -X POST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "refresh_token=$1" \
    "https://slack.com/api/tooling.tokens.rotate"
}

# Performs one rotation attempt and leaves the winning entry (ours or a
# concurrent process's) in the global LAST_ENTRY as a Vault-envelope JSON
# blob shaped like kv_read's output, so callers can pull app_config_token /
# expires_at from it uniformly regardless of which branch won.
LAST_ENTRY=""
do_rotate() {
  require_env
  local bao_tok entry cur_refresh cur_ver slack_resp ok

  bao_tok="$(bao_login)"
  entry="$(kv_read "${bao_tok}")" || die "reading ${kv_path} failed"
  cur_refresh="$(jq -r '.data.data.app_config_refresh_token // empty' <<<"${entry}")"
  cur_ver="$(jq -r '.data.metadata.version // 0' <<<"${entry}")"
  [ -n "${cur_refresh}" ] || die "no app_config_refresh_token at ${kv_path} — needs manual regeneration at api.slack.com"

  slack_resp="$(slack_rotate "${cur_refresh}")" || die "Slack tooling.tokens.rotate call failed"
  ok="$(jq -r '.ok // false' <<<"${slack_resp}")"

  if [ "${ok}" != "true" ]; then
    local err latest latest_ver
    err="$(jq -r '.error // "unknown"' <<<"${slack_resp}")"
    warn "rotation rejected by Slack (${err}) — checking whether another process already rotated"
    latest="$(kv_read "${bao_tok}")" \
      || die "Slack rejected rotation (${err}) and re-reading ${kv_path} also failed — credential needs manual regeneration at api.slack.com"
    latest_ver="$(jq -r '.data.metadata.version // 0' <<<"${latest}")"
    if [ "${latest_ver}" -gt "${cur_ver}" ]; then
      warn "another process rotated first (version ${cur_ver} -> ${latest_ver}); adopting their result"
      LAST_ENTRY="${latest}"
      return 0
    fi
    die "Slack rejected rotation (${err}) and no newer credential appeared at ${kv_path} — the stored refresh token is dead; this credential needs MANUAL REGENERATION at api.slack.com"
  fi

  local new_tok new_refresh exp_epoch rotated_at expires_at code tries=0 backoff="${write_retry_backoff}"
  new_tok="$(jq -r '.token // empty' <<<"${slack_resp}")"
  new_refresh="$(jq -r '.refresh_token // empty' <<<"${slack_resp}")"
  exp_epoch="$(jq -r '.exp // empty' <<<"${slack_resp}")"
  [ -n "${new_tok}" ] && [ -n "${new_refresh}" ] && [ -n "${exp_epoch}" ] \
    || die "Slack rotation response missing token/refresh_token/exp"

  rotated_at="$("${date_bin}" -u +%Y-%m-%dT%H:%M:%SZ)"
  expires_at="$("${date_bin}" -u -r "${exp_epoch}" +%Y-%m-%dT%H:%M:%SZ)"

  # Slack already burned the old refresh token by this point. Losing this
  # write loses the only copy of the new pair, so retry it — bounded, with
  # backoff — before admitting defeat.
  while :; do
    code="$(kv_write_cas "${bao_tok}" "${cur_ver}" "${new_tok}" "${new_refresh}" "${rotated_at}" "${expires_at}")"
    if [ "${code}" = "200" ]; then
      warn "rotated Slack app config token (version ${cur_ver} -> $((cur_ver + 1))); new token expires ${expires_at}"
      LAST_ENTRY="$(jq -cn --arg t "${new_tok}" --arg r "${new_refresh}" --arg ra "${rotated_at}" \
        --arg ea "${expires_at}" --argjson v "$((cur_ver + 1))" \
        '{data: {data: {app_config_token: $t, app_config_refresh_token: $r, rotated_at: $ra, expires_at: $ea}, metadata: {version: $v}}}')"
      return 0
    fi
    if [ "${code}" = "400" ]; then
      # A concurrent writer landed between our read and our write — use
      # their result rather than retrying our own (STEP 4 of the contract:
      # never retry a rotation once a write has been superseded).
      warn "write-back CAS rejected (version ${cur_ver} already superseded); adopting the concurrent writer's result"
      LAST_ENTRY="$(kv_read "${bao_tok}")" || die "CAS rejected and re-reading ${kv_path} failed"
      return 0
    fi
    tries=$((tries + 1))
    if [ "${tries}" -ge "${max_write_retries}" ]; then
      echo "$prefix ERROR write-back to ${kv_path} failed after ${max_write_retries} attempts (HTTP ${code})." >&2
      echo "$prefix ERROR Slack already rotated successfully — the fresh pair exists only in this" >&2
      echo "$prefix ERROR process's memory and was never saved. The stored refresh token is now dead." >&2
      echo "$prefix ERROR This credential is BRICKED and needs manual regeneration at api.slack.com." >&2
      exit 1
    fi
    warn "write-back to ${kv_path} failed (HTTP ${code}), retrying in ${backoff}s (attempt ${tries}/${max_write_retries})"
    sleep "${backoff}"
    backoff=$((backoff * 2))
  done
}

# The one path to a usable token — token/rotate and the manifest commands all
# go through this, so AppRole login (bao_login) is the ONLY credential this
# tool ever produces or accepts. No break-glass, no operator-supplied token.
get_valid_token() {
  require_env
  local bao_tok entry tok expires_at
  bao_tok="$(bao_login)"
  entry="$(kv_read "${bao_tok}")" || die "reading ${kv_path} failed"
  tok="$(jq -r '.data.data.app_config_token // empty' <<<"${entry}")"
  expires_at="$(jq -r '.data.data.expires_at // empty' <<<"${entry}")"
  if [ -z "${tok}" ] || needs_rotation "${expires_at}"; then
    do_rotate
    tok="$(jq -r '.data.data.app_config_token // empty' <<<"${LAST_ENTRY}")"
  fi
  [ -n "${tok}" ] || die "no app_config_token available after rotation attempt"
  printf '%s' "${tok}"
}

cmd_token() {
  get_valid_token
  echo
}

cmd_rotate() {
  require_env
  do_rotate
  local expires_at
  expires_at="$(jq -r '.data.data.expires_at // "unknown"' <<<"${LAST_ENTRY}")"
  echo "$prefix rotation complete; token now expires ${expires_at}" >&2
}

# Reads a manifest JSON file and returns it compacted; used by both manifest
# subcommands so a malformed file is rejected identically either way.
read_manifest() {
  local path="$1"
  [ -f "${path}" ] || die "manifest file not found: ${path}"
  jq -c . "${path}" 2>/dev/null || die "manifest file is not valid JSON: ${path}"
}

cmd_manifest_create() {
  local path="${1:?usage: openbao-slack-creds manifest-create <path-to-manifest.json>}"
  local manifest tok resp ok
  manifest="$(read_manifest "${path}")"
  tok="$(get_valid_token)"
  resp="$("${curl_bin}" -sf --max-time 15 -X POST \
    -H "Authorization: Bearer ${tok}" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "$(jq -cn --argjson m "${manifest}" '{manifest: $m}')" \
    "https://slack.com/api/apps.manifest.create")" || die "apps.manifest.create call failed"
  ok="$(jq -r '.ok // false' <<<"${resp}")"
  [ "${ok}" = "true" ] || die "apps.manifest.create rejected: $(jq -c '.errors // .error // "unknown"' <<<"${resp}")"
  local app_id
  app_id="$(jq -r '.app_id // empty' <<<"${resp}")"
  printf 'app_id=%s\n' "${app_id}"
  printf 'oauth_authorize_url=%s\n' "$(jq -r '.oauth_authorize_url // empty' <<<"${resp}")"
  persist_app_credentials "${app_id}" "${resp}" "${manifest}"
}

# client_id/client_secret/verification_token/signing_secret are issued once,
# at creation, with no API to re-fetch client_secret later — losing this
# write loses them permanently. Stored at
# secrets-external/data/platform/slack-app-<lowercased app_id> with cas:0
# (create-only: refuses to ever overwrite a previous app's credentials).
# Values are never printed; only the storage path is, so an operator can
# find them.
persist_app_credentials() {
  local app_id="$1" create_resp="$2" manifest="$3" creds app_name created_at path body bao_tok code
  creds="$(jq -c '.credentials // empty' <<<"${create_resp}")"
  [ -n "${creds}" ] && [ "${creds}" != "null" ] || return 0

  app_name="$(jq -r '.display_information.name // empty' <<<"${manifest}")"
  created_at="$("${date_bin}" -u +%Y-%m-%dT%H:%M:%SZ)"
  path="secrets-external/data/platform/slack-app-$(printf '%s' "${app_id}" | tr '[:upper:]' '[:lower:]')"
  body="$(jq -cn --argjson c "${creds}" --arg an "${app_name}" --arg ca "${created_at}" \
    '{options: {cas: 0}, data: ($c + {app_name: $an, created_at: $ca})}')"

  bao_tok="$(bao_login)"
  code="$("${curl_bin}" -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST \
    -H "X-Vault-Token: ${bao_tok}" -d "${body}" "${bao_addr}/v1/${path}")"

  if [ "${code}" = "200" ]; then
    echo "$prefix app credentials written to ${path}" >&2
    return 0
  fi

  echo "$prefix ERROR app ${app_id} was created at Slack, but its credentials could NOT be stored at ${path} and are UNRECOVERABLE — Slack has no API to re-fetch client_secret." >&2
  if [ "${code}" = "403" ]; then
    echo "$prefix ERROR OpenBao denied the write (HTTP 403): the slack-admin policy lacks 'create' on ${path} — see the follow-up policy PR in ansible-proxmox-apps." >&2
  else
    echo "$prefix ERROR OpenBao write to ${path} failed (HTTP ${code})." >&2
  fi
  exit 1
}

# Dry-run check against apps.manifest.validate. Tier 3 on Slack's side (no
# rotation consumed there); still goes through get_valid_token like every
# other call, so it is bound by the same rotation/safety-margin logic.
cmd_manifest_validate() {
  local path="${1:?usage: openbao-slack-creds manifest-validate <path-to-manifest.json>}"
  local manifest tok resp ok
  manifest="$(read_manifest "${path}")"
  tok="$(get_valid_token)"
  resp="$("${curl_bin}" -sf --max-time 15 -X POST \
    -H "Authorization: Bearer ${tok}" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "$(jq -cn --argjson m "${manifest}" '{manifest: $m}')" \
    "https://slack.com/api/apps.manifest.validate")" || die "apps.manifest.validate call failed"
  ok="$(jq -r '.ok // false' <<<"${resp}")"
  [ "${ok}" = "true" ] || die "apps.manifest.validate rejected: $(jq -c '.errors // .error // "unknown"' <<<"${resp}")"
  echo "$prefix manifest valid" >&2
}

# --- Channel management ------------------------------------------------
#
# Uses the bot token at slack_ops_kv_path, NOT the app-config token above —
# that token can only call apps.manifest.*. See the SECRET-ZERO block at the
# top of this file. This app has token rotation disabled, so unlike
# slack-admin's app_config_token there is no expiry/rotation logic here:
# get_bot_token just reads the stored value.

slack_ops_kv_path="secrets-external/data/platform/slack-ops"

bao_login_slack_ops() {
  local role_id secret_id resp token
  role_id="${OPENBAO_APPROLE_SLACK_OPS_ROLE_ID:-}"
  secret_id="${OPENBAO_APPROLE_SLACK_OPS_SECRET_ID:-}"
  [ -n "${role_id}" ] && [ -n "${secret_id}" ] || \
    die "OPENBAO_APPROLE_SLACK_OPS_ROLE_ID / OPENBAO_APPROLE_SLACK_OPS_SECRET_ID not in environment — run under 'doppler run'"
  resp="$("${curl_bin}" -sf --max-time 10 -X POST \
    -d "{\"role_id\":\"${role_id}\",\"secret_id\":\"${secret_id}\"}" \
    "${bao_addr}/v1/auth/approle/login")" \
    || die "AppRole login (SLACK_OPS) failed — verify OPENBAO_APPROLE_SLACK_OPS_ROLE_ID/_SECRET_ID are correct and the slack-ops AppRole exists in OpenBao"
  token="$(jq -r '.auth.client_token // empty' <<<"${resp}")"
  [ -n "${token}" ] || die "AppRole login (SLACK_OPS) returned no client_token"
  printf '%s' "${token}"
}

get_bot_token() {
  require_env
  local bao_tok resp tok
  bao_tok="$(bao_login_slack_ops)"
  resp="$("${curl_bin}" -sf --max-time 10 -H "X-Vault-Token: ${bao_tok}" \
    "${bao_addr}/v1/${slack_ops_kv_path}")" || die "reading ${slack_ops_kv_path} failed"
  tok="$(jq -r '.data.data.bot_token // empty' <<<"${resp}")"
  [ -n "${tok}" ] || die "${slack_ops_kv_path} response missing bot_token"
  printf '%s' "${tok}"
}

# GET a Slack Web API method with the bot token. Dies on transport failure
# or `.ok:false` — every caller gets the same missing_scope handling as
# slack_post below.
slack_get() {
  local tok="$1" url="$2" resp
  resp="$("${curl_bin}" -sf --max-time 15 -H "Authorization: Bearer ${tok}" "${url}")" \
    || die "Slack request to ${url} failed"
  slack_check_ok "${resp}" "${url}"
  printf '%s' "${resp}"
}

# POST a JSON body to a Slack Web API method with the bot token.
slack_post() {
  local tok="$1" method="$2" body="$3" resp
  resp="$("${curl_bin}" -sf --max-time 15 -X POST \
    -H "Authorization: Bearer ${tok}" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "${body}" \
    "https://slack.com/api/${method}")" || die "Slack ${method} call failed"
  slack_check_ok "${resp}" "${method}"
  printf '%s' "${resp}"
}

# Shared `.ok` check for slack_get/slack_post. missing_scope gets a message
# naming the specific scope Slack says is needed, since "missing_scope"
# alone doesn't say which one.
slack_check_ok() {
  local resp="$1" what="$2" ok err
  ok="$(jq -r '.ok // false' <<<"${resp}")"
  [ "${ok}" = "true" ] && return 0
  err="$(jq -r '.error // "unknown"' <<<"${resp}")"
  if [ "${err}" = "missing_scope" ]; then
    die "Slack ${what} rejected: missing_scope — needed '$(jq -r '.needed // "unknown"' <<<"${resp}")', bot token has '$(jq -r '.provided // "unknown"' <<<"${resp}")'"
  fi
  die "Slack ${what} rejected: ${err}"
}

# Resolves a channel ID or name to an ID. IDs (C...) pass through unchanged;
# names are looked up via a paginated conversations.list scan. No match, or
# more than one match, dies rather than guessing.
resolve_channel() {
  local tok="$1" input="$2"
  case "${input}" in
    C*) printf '%s' "${input}"; return 0 ;;
  esac
  local cursor="" url page ids matches=()
  while :; do
    url="https://slack.com/api/conversations.list?limit=200&types=public_channel,private_channel"
    [ -n "${cursor}" ] && url="${url}&cursor=${cursor}"
    page="$(slack_get "${tok}" "${url}")"
    ids="$(jq -r --arg n "${input}" '.channels[] | select(.name == $n) | .id' <<<"${page}")"
    if [ -n "${ids}" ]; then
      while IFS= read -r id; do matches+=("${id}"); done <<<"${ids}"
    fi
    cursor="$(jq -r '.response_metadata.next_cursor // empty' <<<"${page}")"
    [ -n "${cursor}" ] || break
  done
  case "${#matches[@]}" in
    0) die "no channel named '${input}' found" ;;
    1) printf '%s' "${matches[0]}" ;;
    *) die "channel name '${input}' is ambiguous (matched ${#matches[@]} channels)" ;;
  esac
}

# conversations.info, used by archive to log the name it resolved to.
channel_name_of() {
  local tok="$1" id="$2"
  jq -r '.channel.name // "unknown"' <<<"$(slack_get "${tok}" "https://slack.com/api/conversations.info?channel=${id}")"
}

cmd_channel_list() {
  local include_archived="" tok cursor="" url page
  [ "${1:-}" = "--include-archived" ] && include_archived=1
  tok="$(get_bot_token)"
  while :; do
    url="https://slack.com/api/conversations.list?limit=200&types=public_channel,private_channel"
    if [ -n "${include_archived}" ]; then
      url="${url}&exclude_archived=false"
    else
      url="${url}&exclude_archived=true"
    fi
    [ -n "${cursor}" ] && url="${url}&cursor=${cursor}"
    page="$(slack_get "${tok}" "${url}")"
    jq -r '.channels[] | [.id, .name, (.is_archived // false | tostring)] | @tsv' <<<"${page}"
    cursor="$(jq -r '.response_metadata.next_cursor // empty' <<<"${page}")"
    [ -n "${cursor}" ] || break
  done
}

cmd_channel_create() {
  local name="" private="" tok body resp id
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --private) private=1; shift ;;
      *) name="$1"; shift ;;
    esac
  done
  [ -n "${name}" ] || die "usage: openbao-slack-creds channel create <name> [--private]"
  tok="$(get_bot_token)"
  if [ -n "${private}" ]; then
    body="$(jq -cn --arg n "${name}" '{name: $n, is_private: true}')"
  else
    body="$(jq -cn --arg n "${name}" '{name: $n}')"
  fi
  resp="$(slack_post "${tok}" "conversations.create" "${body}")"
  id="$(jq -r '.channel.id // empty' <<<"${resp}")"
  [ -n "${id}" ] || die "conversations.create response missing channel.id"
  printf '%s\n' "${id}"
}

cmd_channel_rename() {
  local id_or_name="${1:?usage: openbao-slack-creds channel rename <id-or-name> <new-name>}"
  local new_name="${2:?usage: openbao-slack-creds channel rename <id-or-name> <new-name>}"
  local tok id body
  tok="$(get_bot_token)"
  id="$(resolve_channel "${tok}" "${id_or_name}")"
  body="$(jq -cn --arg c "${id}" --arg n "${new_name}" '{channel: $c, name: $n}')"
  slack_post "${tok}" "conversations.rename" "${body}" >/dev/null
}

cmd_channel_topic() {
  local id_or_name="${1:?usage: openbao-slack-creds channel topic <id-or-name> <text>}"
  local text="${2:?usage: openbao-slack-creds channel topic <id-or-name> <text>}"
  local tok id body
  tok="$(get_bot_token)"
  id="$(resolve_channel "${tok}" "${id_or_name}")"
  body="$(jq -cn --arg c "${id}" --arg t "${text}" '{channel: $c, topic: $t}')"
  slack_post "${tok}" "conversations.setTopic" "${body}" >/dev/null
}

cmd_channel_purpose() {
  local id_or_name="${1:?usage: openbao-slack-creds channel purpose <id-or-name> <text>}"
  local text="${2:?usage: openbao-slack-creds channel purpose <id-or-name> <text>}"
  local tok id body
  tok="$(get_bot_token)"
  id="$(resolve_channel "${tok}" "${id_or_name}")"
  body="$(jq -cn --arg c "${id}" --arg t "${text}" '{channel: $c, purpose: $t}')"
  slack_post "${tok}" "conversations.setPurpose" "${body}" >/dev/null
}

cmd_channel_invite() {
  local id_or_name="${1:?usage: openbao-slack-creds channel invite <id-or-name> <user-id>...}"
  shift
  [ "$#" -ge 1 ] || die "usage: openbao-slack-creds channel invite <id-or-name> <user-id>..."
  local tok id users body
  tok="$(get_bot_token)"
  id="$(resolve_channel "${tok}" "${id_or_name}")"
  users="$(IFS=,; echo "$*")"
  body="$(jq -cn --arg c "${id}" --arg u "${users}" '{channel: $c, users: $u}')"
  slack_post "${tok}" "conversations.invite" "${body}" >/dev/null
}

# Slack has no non-admin channel delete; archive is the closest equivalent
# and does not destroy the channel. Logs id + resolved name before acting,
# since this is the one channel op that's hard to undo non-interactively.
cmd_channel_archive() {
  local id_or_name="${1:?usage: openbao-slack-creds channel archive <id-or-name>}"
  local tok id name body
  tok="$(get_bot_token)"
  id="$(resolve_channel "${tok}" "${id_or_name}")"
  name="$(channel_name_of "${tok}" "${id}")"
  echo "$prefix archiving channel ${id} (${name})" >&2
  body="$(jq -cn --arg c "${id}" '{channel: $c}')"
  slack_post "${tok}" "conversations.archive" "${body}" >/dev/null
}

cmd_channel_members() {
  local id_or_name="${1:?usage: openbao-slack-creds channel members <id-or-name>}"
  local tok id cursor="" url page
  tok="$(get_bot_token)"
  id="$(resolve_channel "${tok}" "${id_or_name}")"
  while :; do
    url="https://slack.com/api/conversations.members?channel=${id}&limit=200"
    [ -n "${cursor}" ] && url="${url}&cursor=${cursor}"
    page="$(slack_get "${tok}" "${url}")"
    jq -r '.members[]' <<<"${page}"
    cursor="$(jq -r '.response_metadata.next_cursor // empty' <<<"${page}")"
    [ -n "${cursor}" ] || break
  done
}

cmd_channel() {
  local sub="${1:-}"
  [ "$#" -gt 0 ] && shift
  case "${sub}" in
    list)    cmd_channel_list "$@" ;;
    create)  cmd_channel_create "$@" ;;
    rename)  cmd_channel_rename "$@" ;;
    topic)   cmd_channel_topic "$@" ;;
    purpose) cmd_channel_purpose "$@" ;;
    invite)  cmd_channel_invite "$@" ;;
    archive) cmd_channel_archive "$@" ;;
    members) cmd_channel_members "$@" ;;
    *) die "usage: openbao-slack-creds channel {list [--include-archived]|create <name> [--private]|rename <id-or-name> <new-name>|topic <id-or-name> <text>|purpose <id-or-name> <text>|invite <id-or-name> <user-id>...|archive <id-or-name>|members <id-or-name>} (archive is Slack's non-admin equivalent of delete — channels are not destroyed)" ;;
  esac
}

self_check() {
  require_env
  echo "$prefix self-check: BAO_ADDR set" >&2
  local bao_tok entry tok refresh rotated_at expires_at
  bao_tok="$(bao_login)"
  echo "$prefix self-check: AppRole login OK" >&2
  entry="$(kv_read "${bao_tok}")" || die "self-check: reading ${kv_path} failed"
  echo "$prefix self-check: ${kv_path} readable" >&2
  tok="$(jq -r '.data.data.app_config_token // empty' <<<"${entry}")"
  refresh="$(jq -r '.data.data.app_config_refresh_token // empty' <<<"${entry}")"
  rotated_at="$(jq -r '.data.data.rotated_at // empty' <<<"${entry}")"
  expires_at="$(jq -r '.data.data.expires_at // empty' <<<"${entry}")"
  [ -n "${tok}" ] || die "self-check: app_config_token missing at ${kv_path}"
  [ -n "${refresh}" ] || die "self-check: app_config_refresh_token missing at ${kv_path}"
  [ -n "${rotated_at}" ] || die "self-check: rotated_at missing at ${kv_path}"
  [ -n "${expires_at}" ] || die "self-check: expires_at missing at ${kv_path}"
  echo "$prefix self-check: required keys present (rotated_at=${rotated_at})" >&2
  local exp_epoch now_epoch remaining
  exp_epoch="$(epoch_of "${expires_at}")" || die "self-check: expires_at '${expires_at}' unparseable"
  now_epoch="$("${date_bin}" -u +%s)"
  remaining=$((exp_epoch - now_epoch))
  echo "$prefix self-check: token life remaining ${remaining}s (expires_at=${expires_at})" >&2
  [ "${remaining}" -gt 0 ] || die "self-check: stored token is already expired (expires_at=${expires_at})"
  echo "$prefix self-check OK" >&2
}

case "${1:-}" in
  token)             cmd_token ;;
  rotate)            cmd_rotate ;;
  manifest-create)   shift; cmd_manifest_create "${1:-}" ;;
  manifest-validate) shift; cmd_manifest_validate "${1:-}" ;;
  channel)           shift; cmd_channel "$@" ;;
  --self-check)      self_check ;;
  *) die "usage: openbao-slack-creds {token|rotate|manifest-create <path>|manifest-validate <path>|channel <subcommand>|--self-check}" ;;
esac
