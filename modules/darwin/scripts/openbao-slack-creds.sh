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
# file), --self-check. manifest-create/validate obtain their bearer token
# through the exact same get_valid_token() path as `token`.
#
# SECRET-ZERO is AMBIENT, identical in shape to openbao-github-creds.sh:
# BAO_ADDR (or legacy VAULT_ADDR) + OPENBAO_APPROLE_SLACK_ADMIN_ROLE_ID /
# OPENBAO_APPROLE_SLACK_ADMIN_SECRET_ID, injected by running under
# `doppler run`. AppRole login (bao_login) is the ONLY credential path in
# this file — there is no break-glass, no root-token fallback, and no
# operator-supplied token; every code path that needs a token gets it from
# get_valid_token(), which always goes through bao_login().
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
  printf 'app_id=%s\n' "$(jq -r '.app_id // empty' <<<"${resp}")"
  printf 'oauth_authorize_url=%s\n' "$(jq -r '.oauth_authorize_url // empty' <<<"${resp}")"
  # client_secret/signing_secret ride along in the response but are never
  # printed — note only that they came back, never their values.
  if jq -e '.credentials' >/dev/null 2>&1 <<<"${resp}"; then
    echo "$prefix note: response also returned app credentials (client_secret/signing_secret) — not printed" >&2
  fi
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
  --self-check)      self_check ;;
  *) die "usage: openbao-slack-creds {token|rotate|manifest-create <path>|manifest-validate <path>|--self-check}" ;;
esac
