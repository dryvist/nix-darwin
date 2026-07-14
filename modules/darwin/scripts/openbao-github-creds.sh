#!/usr/bin/env bash
#
# GitHub token provider backed by OpenBao — the git/gh analogue of
# openbao-aws-creds.sh. Retires the local tiered-PAT keychain services
# (GH_PAT_*) by fetching a purpose-scoped GitHub token from OpenBao KV on
# demand. Two invocation modes share one code path:
#
#   1. git credential helper (token never enters the environment):
#        openbao-github-creds get     (reads the credential request on stdin,
#                                      emits `username`/`password`)
#        openbao-github-creds store   (no-op — OpenBao is the store)
#        openbao-github-creds erase   (no-op)
#      Wire via: git config credential."https://github.com".helper \
#        '!openbao-github-creds'   (git appends the operation, so it invokes
#        `openbao-github-creds get`; do NOT add `get` here or it arrives twice).
#
#   2. env export (for `gh` and shell functions that set GITHUB_TOKEN):
#        export GITHUB_TOKEN="$(openbao-github-creds token [purpose])"
#      `gh` and `git`'s existing `gh auth git-credential` helper both honour
#      GITHUB_TOKEN, so this one export cuts over git push AND gh together.
#
# SECRET-ZERO comes from the AMBIENT ENVIRONMENT, not a local keychain —
# identical to openbao-aws-creds.sh after dryvist/nix-darwin#1686: VAULT_ADDR +
# an AppRole role_id/secret_id, injected by running under `doppler run`. There
# is deliberately NO local keychain in this path; Doppler holds the OpenBao
# bootstrap, OpenBao serves the GitHub tokens.
#
# TIER / PURPOSE SELECTION (least privilege, mirrors the old GH_ENV_MODE tiers).
# Purpose comes from $GH_ENV_MODE (or an explicit `token <purpose>` arg), and
# selects BOTH the KV path and which AppRole's secret-zero to read:
#
#   GH_ENV_MODE            -> purpose          -> AppRole env prefix
#   unset/DRYVIST/RESTRICTED  repo-write          GITHUB_READ   (default, always-on)
#   ADMIN                     personal-admin      GITHUB_ADMIN  (elevated)
#   ORG_ADMIN                 org-admin           GITHUB_ADMIN  (elevated)
#   SECRETS_MANAGER           actions-secrets     GITHUB_ADMIN  (elevated)
#   CLASSIC_ADMIN             classic-admin       GITHUB_ADMIN  (elevated)
#   VISICORE                  visicore            GITHUB_ADMIN  (elevated)
#
# The GITHUB_READ AppRole secret-zero is injected by the default Doppler config,
# so the repo-write token is always reachable. The GITHUB_ADMIN secret-zero is
# scoped to a MORE-privileged Doppler config that a plain shell does NOT carry —
# so pulling an admin token requires a deliberate `doppler run --config <admin>`
# step. Doppler config scoping replaces the old elevate-access keychain unlock
# as the "elevated needs a deliberate step" gate.
#
# ponytail: no on-disk token cache (unlike openbao-aws-creds, which caches
# because `aws` calls credential_process on every API request). git/gh invoke a
# credential helper roughly once per fetch/push and cache in-memory for that
# operation, so one AppRole login + one KV read per push is cheap — and the hard
# rule is "never write tokens to disk". Add a cache only if a real workload
# measurably hammers OpenBao.
#
# `pkgs.writeShellApplication` wraps this in `set -euo pipefail` and lints it
# (see the sibling scripts' notes), so this file omits its own set line.

prefix="[openbao-github-creds]"
die() { echo "$prefix ERROR $*" >&2; exit 1; }

# Map the requested tier to (purpose, approle_env_prefix).
resolve_tier() {
  local mode="${1:-${GH_ENV_MODE:-}}"
  case "${mode}" in
    ADMIN)                 purpose="personal-admin"  approle_prefix="GITHUB_ADMIN" ;;
    ORG_ADMIN)             purpose="org-admin"       approle_prefix="GITHUB_ADMIN" ;;
    SECRETS_MANAGER)       purpose="actions-secrets" approle_prefix="GITHUB_ADMIN" ;;
    CLASSIC_ADMIN)         purpose="classic-admin"   approle_prefix="GITHUB_ADMIN" ;;
    VISICORE)              purpose="visicore"        approle_prefix="GITHUB_ADMIN" ;;
    *)                     purpose="repo-write"      approle_prefix="GITHUB_READ"  ;;
  esac
}

# Print the GitHub token for the resolved purpose to stdout.
fetch_token() {
  local explicit_purpose="${1:-}"
  resolve_tier
  [ -n "${explicit_purpose}" ] && purpose="${explicit_purpose}"

  # Indirect-expand the AppRole secret-zero for the chosen tier, e.g.
  # OPENBAO_APPROLE_GITHUB_READ_ROLE_ID / _SECRET_ID.
  local bao_addr role_id_var secret_id_var role_id secret_id
  bao_addr="${VAULT_ADDR:-}"
  role_id_var="OPENBAO_APPROLE_${approle_prefix}_ROLE_ID"
  secret_id_var="OPENBAO_APPROLE_${approle_prefix}_SECRET_ID"
  role_id="${!role_id_var:-}"
  secret_id="${!secret_id_var:-}"
  if [ -z "${bao_addr}" ] || [ -z "${role_id}" ] || [ -z "${secret_id}" ]; then
    die "VAULT_ADDR / ${role_id_var} / ${secret_id_var} not in environment — run under 'doppler run' so the OpenBao bootstrap is injected (purpose=${purpose})"
  fi

  local login_resp token
  login_resp="$(curl -sf --max-time 10 -X POST \
    -d "{\"role_id\":\"${role_id}\",\"secret_id\":\"${secret_id}\"}" \
    "${bao_addr}/v1/auth/approle/login")" || die "AppRole login to ${bao_addr} failed"
  token="$(jq -r '.auth.client_token // empty' <<<"${login_resp}")"
  [ -n "${token}" ] || die "AppRole login returned no client_token"

  local kv_resp gh_token
  kv_resp="$(curl -sf --max-time 10 -H "X-Vault-Token: ${token}" \
    "${bao_addr}/v1/secret/data/github/${purpose}")" || die "reading secret/github/${purpose} failed"
  gh_token="$(jq -r '.data.data.token // empty' <<<"${kv_resp}")"
  [ -n "${gh_token}" ] || die "secret/github/${purpose} has no .data.token"

  printf '%s' "${gh_token}"
}

# git credential protocol: read key=value lines on stdin until a blank line.
git_credential_get() {
  local host="" line
  while IFS= read -r line; do
    [ -z "${line}" ] && break
    case "${line}" in
      host=*) host="${line#host=}" ;;
    esac
  done
  # Only answer for github.com; anything else falls through to the next helper.
  case "${host}" in
    github.com|gist.github.com) : ;;
    *) exit 0 ;;
  esac
  local gh_token
  gh_token="$(fetch_token)"
  printf 'username=x-access-token\npassword=%s\n' "${gh_token}"
}

case "${1:-}" in
  get)         git_credential_get ;;
  store|erase) exit 0 ;;             # OpenBao is the store; nothing to cache/forget.
  token)       fetch_token "${2:-}"; echo ;;
  *) die "usage: openbao-github-creds {get|store|erase|token [purpose]}" ;;
esac
