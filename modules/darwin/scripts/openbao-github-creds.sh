#!/usr/bin/env bash
#
# GitHub token provider backed by OpenBao's GitHub App secrets engine — the
# git/gh analogue of openbao-aws-creds.sh. Retires the local tiered-PAT keychain
# services (GH_PAT_*). Tokens are ephemeral GitHub App installation tokens minted
# on demand; nothing is ever stored (no KV PAT path exists — see the server's
# .claude/rules/openbao-plugins-first.md).
#
# THREE TIERS, mirroring the OpenBao AppRoles of the same name:
#
#   read   github/token/read-<owner>-all   all-repo, read-only. Ambient: any
#          fetch or `gh` read resolves one with zero ceremony.
#   write  raw github/token, scoped to ONE repository per request. Gated by a
#          claim: you must `claim <owner>/<repo>` (which takes a cross-agent
#          lease) before a write token exists.
#   admin  github/token/<...>-full-automation   installation-wide, full ceiling.
#          Inert AppRole: needs a human-wrapped single-use secret_id.
#
# INVOCATION MODES
#
#   1. git credential helper (default read path; token stays out of the shell):
#        openbao-github-creds get      reads the credential request on stdin.
#        openbao-github-creds store/erase   no-ops (OpenBao is the store).
#      If GITHUB_TOKEN is already set (e.g. after `claim`), get echoes it — so a
#      claimed write token flows straight into `git push`. Otherwise get mints a
#      read token for the request's owner. A push with only a read token fails at
#      GitHub (403) — loud and correct: writing requires a claim.
#      Wire via: git config credential."https://github.com".helper \
#        '!openbao-github-creds' ; git config credential."https://github.com".useHttpPath true
#      (useHttpPath makes git send path=<owner>/<repo> so get picks the right
#      read set; get appends `get`, so do NOT add it to the helper string.)
#
#   2. claim / release (per-repo write lease + write token, for the shell):
#        eval "$(openbao-github-creds claim <owner>/<repo>)"
#        ... git push / gh pr ...
#        openbao-github-creds release        (or just exit the shell)
#      claim CAS-acquires secret/locks/github-write/<installation_id>/<repo> so
#      two agents cannot both hold write on one repo, mints a token scoped to
#      that single repo, and prints `export GITHUB_TOKEN=...`. The lease has a
#      server-side deadman (KV-v2 delete_version_after) so a crashed holder frees
#      it automatically.
#
#   3. explicit token to stdout (for scripts / `gh`):
#        export GITHUB_TOKEN="$(openbao-github-creds token read <owner>)"
#        export GITHUB_TOKEN="$(openbao-github-creds token write <owner>/<repo>)"  # takes no lease
#
# SECRET-ZERO is AMBIENT (no local keychain), identical to openbao-aws-creds.sh
# after dryvist/nix-darwin#1686: VAULT_ADDR + the github-read / github-write
# AppRole role_id/secret_id, injected by running under `doppler run`. Write and
# claim additionally need the installation IDs (OPENBAO_GITHUB_DRYVIST_INSTALLATION_ID
# / OPENBAO_GITHUB_PERSONAL_INSTALLATION_ID) so a repo name can be pinned to its
# installation — the values are not secret (they appear in App-install URLs) but
# are injected the same way to keep this committed script free of them.
#
# ponytail: no on-disk token cache and no on-disk token — git/gh call the helper
# ~once per operation and cache in-memory for it; the hard rule is "never write a
# token to disk". The lease lives in OpenBao, not a local file.
#
# `pkgs.writeShellApplication` wraps this in `set -euo pipefail` and lints it, so
# this file omits its own set line.

prefix="[openbao-github-creds]"
die() { echo "$prefix ERROR $*" >&2; exit 1; }

default_owner="${OPENBAO_GH_DEFAULT_OWNER:-dryvist}"

# Owner -> read permission-set name. Owner strings are public; no secret here.
read_set_for() {
  case "$1" in
    dryvist) echo "read-dryvist-all" ;;
    *)       echo "read-personal-all" ;;
  esac
}

# Owner -> installation id, from the ambient env (not committed here).
installation_id_for() {
  case "$1" in
    dryvist) echo "${OPENBAO_GITHUB_DRYVIST_INSTALLATION_ID:-}" ;;
    *)       echo "${OPENBAO_GITHUB_PERSONAL_INSTALLATION_ID:-}" ;;
  esac
}

# Lease holder identity: stable within a login session, distinct across sessions.
lock_holder() {
  echo "${OPENBAO_GH_SESSION:-$(id -un)@$(scutil --get ComputerName 2>/dev/null || hostname -s)}"
}

require_env() {
  [ -n "${VAULT_ADDR:-}" ] || die "VAULT_ADDR not set — run under 'doppler run'"
}

# AppRole login for the given env prefix (GITHUB_READ / GITHUB_WRITE); prints the
# client_token. Secret-zero comes from OPENBAO_APPROLE_<prefix>_ROLE_ID/_SECRET_ID.
bao_login() {
  local approle_prefix="$1" role_id_var secret_id_var role_id secret_id resp token
  role_id_var="OPENBAO_APPROLE_${approle_prefix}_ROLE_ID"
  secret_id_var="OPENBAO_APPROLE_${approle_prefix}_SECRET_ID"
  role_id="${!role_id_var:-}"
  secret_id="${!secret_id_var:-}"
  [ -n "${role_id}" ] && [ -n "${secret_id}" ] || \
    die "${role_id_var} / ${secret_id_var} not in environment — run under 'doppler run'"
  resp="$(curl -sf --max-time 10 -X POST \
    -d "{\"role_id\":\"${role_id}\",\"secret_id\":\"${secret_id}\"}" \
    "${VAULT_ADDR}/v1/auth/approle/login")" || die "AppRole login (${approle_prefix}) failed"
  token="$(jq -r '.auth.client_token // empty' <<<"${resp}")"
  [ -n "${token}" ] || die "AppRole login (${approle_prefix}) returned no client_token"
  printf '%s' "${token}"
}

mint_read() {
  local owner="$1" set_name bao_tok resp gh_tok
  set_name="$(read_set_for "${owner}")"
  bao_tok="$(bao_login GITHUB_READ)"
  resp="$(curl -sf --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" \
    "${VAULT_ADDR}/v1/github/token/${set_name}")" || die "mint read token (${set_name}) failed"
  gh_tok="$(jq -r '.data.token // empty' <<<"${resp}")"
  [ -n "${gh_tok}" ] || die "no token in read mint response (${set_name})"
  printf '%s' "${gh_tok}"
}

# Build the raw-token request body for one repo. Kept separate so --self-check
# can assert its shape without a live server.
# STRING forms are load-bearing (verified live 2026-07-18): OpenBao's ACL
# cannot element-match a LIST-valued parameter and only matches
# installation_id as a string — the server-side allowlist denies the
# number/list forms outright.
write_token_body() {
  local iid="$1" repo="$2"
  jq -cn --arg iid "${iid}" --arg repo "${repo}" \
    '{installation_id: $iid, repositories: $repo}'
}

mint_write() {
  local owner="$1" repo="$2" iid bao_tok body resp gh_tok
  iid="$(installation_id_for "${owner}")"
  [ -n "${iid}" ] || die "no installation id for owner '${owner}' — set OPENBAO_GITHUB_*_INSTALLATION_ID"
  bao_tok="$(bao_login GITHUB_WRITE)"
  body="$(write_token_body "${iid}" "${repo}")"
  resp="$(curl -sf --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" \
    -d "${body}" "${VAULT_ADDR}/v1/github/token")" \
    || die "mint write token for ${owner}/${repo} failed (repo not on the allowlist?)"
  gh_tok="$(jq -r '.data.token // empty' <<<"${resp}")"
  [ -n "${gh_tok}" ] || die "no token in write mint response for ${owner}/${repo}"
  printf '%s' "${gh_tok}"
}

lock_path() { echo "github/token"; }  # documented anchor; real path built inline

# CAS-acquire the per-repo write lease. Refuses if another live holder owns it.
lock_acquire() {
  local iid="$1" repo="$2" bao_tok data_url meta_url cur ver holder me now
  me="$(lock_holder)"
  bao_tok="$(bao_login GITHUB_WRITE)"
  data_url="${VAULT_ADDR}/v1/secret/data/locks/github-write/${iid}/${repo}"
  meta_url="${VAULT_ADDR}/v1/secret/metadata/locks/github-write/${iid}/${repo}"
  # Server-side deadman: each lock version self-deletes, freeing a crashed holder.
  curl -sf --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" \
    -d "{\"delete_version_after\":\"${OPENBAO_GH_LOCK_TTL:-15m}\"}" "${meta_url}" >/dev/null \
    || true
  cur="$(curl -sf --max-time 10 -H "X-Vault-Token: ${bao_tok}" "${data_url}" 2>/dev/null || echo '{}')"
  holder="$(jq -r '.data.data.holder // empty' <<<"${cur}")"
  ver="$(jq -r '.data.metadata.version // 0' <<<"${cur}")"
  if [ -n "${holder}" ] && [ "${holder}" != "${me}" ]; then
    die "repo ${repo} is write-leased by '${holder}' — release it or wait for the lease to expire"
  fi
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local acq
  acq="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' -X POST \
    -H "X-Vault-Token: ${bao_tok}" \
    -d "$(jq -cn --arg h "${me}" --arg t "${now}" --argjson v "${ver}" \
          '{options:{cas:$v}, data:{holder:$h, acquired_at:$t}}')" \
    "${data_url}")"
  [ "${acq}" = "200" ] || die "could not acquire the write lease for ${repo} (raced another agent; HTTP ${acq})"
}

lock_release() {
  local iid="$1" repo="$2" bao_tok meta_url
  bao_tok="$(bao_login GITHUB_WRITE)"
  meta_url="${VAULT_ADDR}/v1/secret/metadata/locks/github-write/${iid}/${repo}"
  curl -sf --max-time 10 -X DELETE -H "X-Vault-Token: ${bao_tok}" "${meta_url}" >/dev/null \
    || echo "$prefix warning: could not release lease for ${repo} (it will expire on its own)" >&2
}

split_repo() {  # "owner/repo" -> sets $owner $repo; defaults owner if bare
  case "$1" in
    */*) owner="${1%%/*}" repo="${1#*/}" ;;
    *)   owner="${default_owner}" repo="$1" ;;
  esac
  [ -n "${repo}" ] || die "expected <owner>/<repo>, got '$1'"
}

cmd_claim() {
  local owner repo iid tok
  require_env
  [ -n "${1:-}" ] || die "usage: openbao-github-creds claim <owner>/<repo>"
  split_repo "$1"
  iid="$(installation_id_for "${owner}")"
  [ -n "${iid}" ] || die "no installation id for owner '${owner}'"
  lock_acquire "${iid}" "${repo}"
  tok="$(mint_write "${owner}" "${repo}")"
  # Emit shell to eval: token in the env, claim recorded, auto-release on exit.
  printf 'export GITHUB_TOKEN=%q;\n' "${tok}"
  printf 'export OPENBAO_GH_CLAIM=%q;\n' "${owner}/${repo}"
  printf 'trap %q EXIT;\n' "openbao-github-creds release >/dev/null 2>&1 || true"
  echo "$prefix claimed write on ${owner}/${repo} (GITHUB_TOKEN set; auto-releases on shell exit)" >&2
}

cmd_release() {
  local target="${1:-${OPENBAO_GH_CLAIM:-}}" owner repo iid
  require_env
  [ -n "${target}" ] || die "nothing to release (no OPENBAO_GH_CLAIM and no arg)"
  split_repo "${target}"
  iid="$(installation_id_for "${owner}")"
  lock_release "${iid}" "${repo}"
  printf 'unset GITHUB_TOKEN OPENBAO_GH_CLAIM;\n'
  echo "$prefix released write lease on ${owner}/${repo}" >&2
}

# git credential protocol: read key=value lines until blank.
cmd_get() {
  local host="" path="" line
  while IFS= read -r line; do
    [ -z "${line}" ] && break
    case "${line}" in
      host=*) host="${line#host=}" ;;
      path=*) path="${line#path=}" ;;
    esac
  done
  case "${host}" in github.com|gist.github.com) : ;; *) exit 0 ;; esac
  # A claimed (or otherwise supplied) token wins — this carries a write token
  # into `git push` without ever putting the read path in charge.
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    printf 'username=x-access-token\npassword=%s\n' "${GITHUB_TOKEN}"
    exit 0
  fi
  require_env
  local owner="${default_owner}"
  case "${path}" in */*) owner="${path%%/*}" ;; esac
  printf 'username=x-access-token\npassword=%s\n' "$(mint_read "${owner}")"
}

cmd_token() {
  require_env
  case "${1:-read}" in
    read)  cmd_token_read "${2:-${default_owner}}" ;;
    write) [ -n "${2:-}" ] || die "usage: openbao-github-creds token write <owner>/<repo>"
           split_repo "$2"; mint_write "${owner}" "${repo}"; echo ;;
    */*|*) cmd_token_read "${1}" ;;   # `token <owner>` shorthand for read
  esac
}
cmd_token_read() { mint_read "$1"; echo; }

self_check() {
  local out
  out="$(write_token_body 147266792 nix-darwin)"
  [ "${out}" = '{"installation_id":"147266792","repositories":"nix-darwin"}' ] \
    || { echo "self-check FAIL: write body = ${out}"; return 1; }
  owner=""; repo=""; split_repo "dryvist/nix-darwin"
  [ "${owner}" = "dryvist" ] && [ "${repo}" = "nix-darwin" ] \
    || { echo "self-check FAIL: split owner=${owner} repo=${repo}"; return 1; }
  owner=""; repo=""; split_repo "loose-repo"
  [ "${owner}" = "${default_owner}" ] && [ "${repo}" = "loose-repo" ] \
    || { echo "self-check FAIL: bare split owner=${owner} repo=${repo}"; return 1; }
  [ "$(read_set_for dryvist)" = "read-dryvist-all" ] \
    && [ "$(read_set_for JacobPEvans-personal)" = "read-personal-all" ] \
    || { echo "self-check FAIL: read_set mapping"; return 1; }
  echo "self-check OK"
}

case "${1:-}" in
  get)          cmd_get ;;
  store|erase)  exit 0 ;;
  claim)        cmd_claim "${2:-}" ;;
  release)      cmd_release "${2:-}" ;;
  token)        shift; cmd_token "$@" ;;
  --self-check) self_check ;;
  *) die "usage: openbao-github-creds {get|store|erase|claim <owner>/<repo>|release [<owner>/<repo>]|token [read|write] [<owner>[/<repo>]]|--self-check}" ;;
esac
