#!/usr/bin/env bash
#
# GitHub token provider backed by OpenBao's GitHub App secrets engine — the
# git/gh analogue of openbao-aws-creds.sh. Retires the local tiered-PAT keychain
# services (GH_PAT_*). Tokens are ephemeral GitHub App installation tokens minted
# on demand; nothing is ever stored (no KV PAT path exists — see the server's
# .claude/rules/openbao-plugins-first.md).
#
# TIERS, mirroring the OpenBao AppRoles of the same name:
#
#   read         github/token/read-<owner>-all   all-repo, read-only. Ambient:
#                any fetch or `gh` read resolves one with zero ceremony.
#   write        raw github/token, scoped to ONE repository per request. Gated
#                by a claim: you must `claim <owner>/<repo>` (which takes a
#                cross-agent lease) before a write token exists.
#   repo-create  github/token/<owner>-repo-create   installation-wide,
#                permission map exactly {administration: write}. Unlike read
#                and write, this credential is never handed to the caller: the
#                `repo-create` ACTION (below) mints it, spends it on exactly
#                one repository-creation call, and revokes it — creating a
#                repo does not itself grant write; the caller still adds it to
#                OPENBAO_GITHUB_WRITE_REPOS and converges before `token write`
#                will mint for it.
#   admin        github/token/<...>-full-automation   installation-wide, full
#                ceiling. Inert AppRole: needs a human-wrapped single-use
#                secret_id.
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
#      There is no `token repo-create`: administration:write is never printed
#      or captured — see repo-create below.
#
#   3b. repo-create <owner>/<repo> [private|public] — create a repository. An
#       ACTION, not a token verb: mints the repo-create credential, spends it
#       on exactly one API call, revokes it, and never prints it. Runs
#       non-interactively (refuse_tty, like every other verb here) — the
#       escalation gate is the operator-provisioned
#       OPENBAO_APPROLE_GITHUB_REPO_CREATE_ROLE_ID/_SECRET_ID pair, not a
#       terminal prompt. Prints the new repo's html_url, then one line naming
#       the next step (add it to OPENBAO_GITHUB_WRITE_REPOS and converge).
#
#   4. break-glass (OpenBao is unreachable): mint straight from the GitHub App
#      key, bypassing OpenBao's mint path entirely. Same security posture as the
#      normal path — ephemeral (~1h) installation token, minimally scoped — but a
#      DIFFERENT failure domain (needs only api.github.com + the App key, not the
#      OpenBao guest's DNS/egress). Use ONLY when tiers 1-3 are down; it does not
#      take a write lease, so coordinate manually.
#        export GITHUB_TOKEN="$(openbao-github-creds break-glass read <owner>)"
#        export GITHUB_TOKEN="$(openbao-github-creds break-glass write <owner>/<repo>)"
#      The default read scope is contents/issues/PRs/checks/actions/statuses read;
#      write adds contents/PRs/issues write, scoped to the one named repo. The App
#      key (OPENBAO_GITHUB_APP_ID / OPENBAO_GITHUB_APP_PRIVATE_KEY) rides the same
#      ambient doppler env; it is the App's FULL ceiling, so break-glass always
#      pins an explicit minimal permissions scope on the mint request rather than
#      taking the installation default.
#
# SECRET-ZERO is AMBIENT (no local keychain), identical to openbao-aws-creds.sh
# after dryvist/nix-darwin#1686: BAO_ADDR (or legacy VAULT_ADDR) + the github-read / github-write
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

# writeShellApplication's `set -e` (see header) is not, by default, inherited
# into a command substitution's own subshell one level further down — a die()
# two levels deep (e.g. repo_create_set_for, called from inside
# mint_repo_create's own "$(...)", called from inside cmd_repo_create's
# "$(...)") would print its error and let the OUTER caller keep going with an
# empty value instead of aborting. inherit_errexit (bash 4.4+) closes that gap
# for this and every future nested command substitution in the file.
shopt -s inherit_errexit

# Refusing to write a credential to a terminal.
#
# Every subcommand below exists to be CAPTURED -- `export X="$(...)"` or
# `eval "$(...)"` -- so in correct use stdout is a pipe. A terminal on stdout
# means a human or an agent ran it directly to "see if it works", and the value
# lands in scrollback or a session transcript, which outlive the credential
# itself. That has happened; it is a usability trap in this tool rather than a
# user error, so the tool refuses rather than relying on everyone remembering.
refuse_tty() {
  [ -t 1 ] || return 0
  die "refusing to print a credential to a terminal. It would persist in scrollback and session transcripts long after the token itself expires. Capture it instead: export GITHUB_TOKEN=\"\$(openbao-github-creds token read <owner>)\", or eval \"\$(openbao-github-creds claim <owner>/<repo>)\" for a write lease."
}


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

bao_addr="${BAO_ADDR:-${VAULT_ADDR:-}}"

require_env() {
  [ -n "${bao_addr}" ] || die "BAO_ADDR not set — run under 'doppler run'"
}

# Resolve the env-var NAMES secret-zero lives in for one AppRole prefix, into
# the caller's role_id_var / secret_id_var. Derived in exactly ONE place because
# it has three readers that must never disagree: bao_login reads the values,
# bao_login_configured tests them, and the self-check has to tell "never
# configured on this machine" apart from "configured, and the login failed".
bao_login_var_names() {
  role_id_var="OPENBAO_APPROLE_${1}_ROLE_ID"
  secret_id_var="OPENBAO_APPROLE_${1}_SECRET_ID"
}

# True when this machine was given secret-zero for the prefix. Says nothing
# about whether a login would SUCCEED — that distinction is the whole point.
bao_login_configured() {
  local role_id_var secret_id_var
  bao_login_var_names "$1"
  [ -n "${!role_id_var:-}" ] && [ -n "${!secret_id_var:-}" ]
}

# AppRole login for the given env prefix (GITHUB_READ / GITHUB_WRITE); prints the
# client_token. Secret-zero comes from OPENBAO_APPROLE_<prefix>_ROLE_ID/_SECRET_ID.
#
# NEVER SUPPRESS A FAILURE FROM THIS FUNCTION WITH `||`. Every call site is a
# command substitution, so die()'s `exit 1` ends only that SUBSHELL; what
# actually aborts the caller is the `set -o errexit` that writeShellApplication
# wraps this file in (see the header note). A plain assignment is therefore
# safe. Attaching `|| ...` to one turns errexit OFF for that command, and the
# caller then continues with an EMPTY token — so a login that could not
# complete becomes a request made with an empty X-Vault-Token, and whatever
# the caller reports afterwards is reported as though the credential were fine.
#
# That "errexit reliably aborts" claim has a hole: POSIX exempts a command
# that is the condition of `if`/`while`/`until`, or a non-final member of an
# `&&`/`||` list, from errexit — and every caller here is reached through
# self_check's own `fn || return 1` dispatch (or an `if out="$(...)"; then`
# around it), which puts THIS assignment inside exactly that exemption.
# `shopt -s inherit_errexit` propagates the exemption into every nested
# command substitution below it, so a bare assignment is NOT actually safe in
# this file. Every caller MUST follow its `bao_tok="$(bao_login ...)"` with
# `require_tok "${bao_tok}" ...` (below) rather than trusting errexit alone.
bao_login() {
  local approle_prefix="$1" role_id_var secret_id_var role_id secret_id resp token
  bao_login_var_names "${approle_prefix}"
  bao_login_configured "${approle_prefix}" || \
    die "${role_id_var} / ${secret_id_var} not in environment — run under 'doppler run'"
  role_id="${!role_id_var}"
  secret_id="${!secret_id_var}"
  # Credential travels via a private payload on stdin, never argv (argv is
  # visible to any local process via ps).
  resp="$(jq -n --arg r "${role_id}" --arg s "${secret_id}" '{role_id: $r, secret_id: $s}' \
    | curl -sf --max-time 10 -X POST --data-binary @- \
        "${bao_addr}/v1/auth/approle/login")" || die "AppRole login (${approle_prefix}) failed"
  token="$(jq -r '.auth.client_token // empty' <<<"${resp}")"
  [ -n "${token}" ] || die "AppRole login (${approle_prefix}) returned no client_token"
  printf '%s' "${token}"
}

# The reliable half of every `bao_tok="$(bao_login ...)"` capture — see the
# comment on bao_login above for why the assignment alone cannot be trusted
# to abort on failure here. Halts unconditionally, independent of errexit.
require_tok() {
  [ -n "$1" ] || die "AppRole login (${2}) returned no token"
}

# Which AppRole identity mints writes for a repository.
#
# Most repositories use the single organisation-wide write identity. A
# repository may instead belong to a WRITE REALM: its own policy and AppRole
# with its own allowlist, so that a narrower group of repositories is not
# reachable by the organisation-wide credential and vice versa.
#
# Realms are described by OPENBAO_GITHUB_WRITE_SCOPES, the SAME variable the
# openbao role reads to render the policies — one definition drives both the
# server-side boundary and this client-side routing, so they cannot disagree.
# Shape: {"<realm-name>": ["repo", ...]}. Unset, or a repository named in no
# realm, yields the default identity; that fallback is what keeps this change
# inert until realms exist.
#
# The realm name becomes the AppRole env-var prefix the same way every other
# prefix is formed: upper-cased, non-alphanumerics to underscores.
write_login_prefix_for() {
  local repo="$1" scopes realm
  scopes="${OPENBAO_GITHUB_WRITE_SCOPES:-}"
  if [ -n "${scopes}" ]; then
    # `index` on the repo list, not string matching: a realm holding "docs"
    # must not claim "docs-internal".
    realm="$(jq -r --arg r "${repo}" \
      'to_entries | map(select(.value | index($r))) | .[0].key // empty' \
      <<<"${scopes}" 2>/dev/null || true)"
    if [ -n "${realm}" ]; then
      printf '%s' "${realm}" | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_'
      return
    fi
  fi
  printf 'GITHUB_WRITE'
}

mint_read() {
  local owner="$1" set_name bao_tok resp gh_tok
  set_name="$(read_set_for "${owner}")"
  bao_tok="$(bao_login GITHUB_READ)"
  require_tok "${bao_tok}" GITHUB_READ
  resp="$(curl -sf --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" \
    "${bao_addr}/v1/github/token/${set_name}")" || die "mint read token (${set_name}) failed"
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
  local owner="$1" repo="$2" iid bao_tok body resp gh_tok prefix
  iid="$(installation_id_for "${owner}")"
  [ -n "${iid}" ] || die "no installation id for owner '${owner}' — set OPENBAO_GITHUB_*_INSTALLATION_ID"
  prefix="$(write_login_prefix_for "${repo}")"
  bao_tok="$(bao_login "${prefix}")"
  require_tok "${bao_tok}" "${prefix}"
  body="$(write_token_body "${iid}" "${repo}")"
  resp="$(printf '%s' "${body}" \
    | curl -sf --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" --data-binary @- \
        "${bao_addr}/v1/github/token")" \
    || die "mint write token for ${owner}/${repo} failed (identity: ${prefix}).
Most likely ${repo} is not on the allowlist this identity is pinned to. That is
a deny, not a bug, and there is no client-side workaround — do NOT fall back to
a personal access token or any other standing credential to complete the write.

If the identity above is GITHUB_WRITE, add the repository name to
OPENBAO_GITHUB_WRITE_REPOS in the iac secret store (comma-separated; the
ansible-proxmox-apps openbao role reads it into
openbao_github_write_repo_allowlist).

Otherwise ${repo} belongs to a write realm and the name must be on THAT realm's
list inside OPENBAO_GITHUB_WRITE_SCOPES — adding it to the organisation-wide
list instead would defeat the boundary the realm exists to draw.

Either way the change is not live until the openbao role is converged. If the
name is already listed, re-check that the converge actually ran."
  gh_tok="$(jq -r '.data.token // empty' <<<"${resp}")"
  [ -n "${gh_tok}" ] || die "no token in write mint response for ${owner}/${repo}"
  printf '%s' "${gh_tok}"
}

# repo-create is a permission set (like read), not the raw allowlisted
# endpoint (like write) — nothing to scope before the repo exists. Only
# dryvist is provisioned: installation tokens cannot create USER-owned repos
# at all (GitHub has no `POST /user/repos` equivalent for an App
# installation token — that endpoint only works for a personal OAuth/PAT
# token), so there is no path to add here for a personal owner.
repo_create_set_for() {
  case "$1" in
    dryvist) echo "dryvist-repo-create" ;;
    *)       die "repo-create is not available for owner '$1' — only 'dryvist' is provisioned. Installation tokens cannot create user-owned repositories (no POST /user/repos equivalent for an App installation token)." ;;
  esac
}

mint_repo_create() {
  local owner="$1" set_name bao_tok resp gh_tok
  set_name="$(repo_create_set_for "${owner}")"
  bao_tok="$(bao_login GITHUB_REPO_CREATE)"
  require_tok "${bao_tok}" GITHUB_REPO_CREATE
  resp="$(curl -sf --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" \
    "${bao_addr}/v1/github/token/${set_name}")" || die "mint repo-create token (${set_name}) failed"
  gh_tok="$(jq -r '.data.token // empty' <<<"${resp}")"
  [ -n "${gh_tok}" ] || die "no token in repo-create mint response (${set_name})"
  printf '%s' "${gh_tok}"
}

# --- break-glass: mint direct from the App key, bypassing OpenBao -------------
# base64url without padding (RFC 7515) — for the JWT header/payload/signature.
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# Mint an ephemeral installation token straight from the GitHub App key, pinning
# an explicit minimal permissions scope (the App key is the full ceiling, so we
# never take the installation default). $2 is a JSON permissions object; $3 is a
# comma-repo list ("" = every repo in the installation, for read).
mint_break_glass() {
  local owner="$1" scope_json="$2" repos="$3" iid now hdr pl unsigned sig jwt body resp gh_tok
  [ -n "${OPENBAO_GITHUB_APP_ID:-}" ] \
    || die "break-glass needs OPENBAO_GITHUB_APP_ID (run under 'doppler run')"
  [ -n "${OPENBAO_GITHUB_APP_PRIVATE_KEY:-}" ] \
    || die "break-glass needs OPENBAO_GITHUB_APP_PRIVATE_KEY (run under 'doppler run')"
  iid="$(installation_id_for "${owner}")"
  [ -n "${iid}" ] || die "no installation id for owner '${owner}'"
  now="$(date +%s)"
  hdr="$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)"
  # App JWT: 9-min life, iat backdated 60s for clock skew (GitHub's own guidance).
  pl="$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' \
        "$((now - 60))" "$((now + 540))" "${OPENBAO_GITHUB_APP_ID}" | b64url)"
  unsigned="${hdr}.${pl}"
  # Sign with the key piped in via process substitution — the private key never
  # touches disk (no temp file to leak or leave behind).
  sig="$(printf '%s' "${unsigned}" \
    | openssl dgst -sha256 -sign <(printf '%s\n' "${OPENBAO_GITHUB_APP_PRIVATE_KEY}") \
    | b64url)"
  jwt="${unsigned}.${sig}"
  if [ -n "${repos}" ]; then
    body="$(jq -cn --argjson p "${scope_json}" --arg r "${repos}" \
      '{permissions: $p, repositories: ($r | split(","))}')"
  else
    body="$(jq -cn --argjson p "${scope_json}" '{permissions: $p}')"
  fi
  resp="$(printf '%s' "${body}" \
    | curl -sf --max-time 15 -X POST \
        -H "Authorization: Bearer ${jwt}" -H "Accept: application/vnd.github+json" \
        --data-binary @- "https://api.github.com/app/installations/${iid}/access_tokens")" \
    || die "break-glass mint failed for ${owner} (App key valid? api.github.com reachable?)"
  gh_tok="$(jq -r '.token // empty' <<<"${resp}")"
  [ -n "${gh_tok}" ] || die "no token in break-glass response for ${owner}"
  printf '%s' "${gh_tok}"
}

# Minimal everyday-task scopes. Read: pull/inspect PRs, issues, checks, CI.
# Write: push + PR/issue authoring, scoped to ONE repo; checks/actions stay read.
bg_read_scope='{"contents":"read","metadata":"read","issues":"read","pull_requests":"read","checks":"read","actions":"read","statuses":"read"}'
bg_write_scope='{"contents":"write","pull_requests":"write","issues":"write","metadata":"read","checks":"read","actions":"read","statuses":"read"}'

cmd_break_glass() {
  refuse_tty "$@"
  # split_repo assigns owner/repo; scope them here so a break-glass call cannot
  # leave them set for anything that runs afterwards.
  local owner repo
  case "${1:-read}" in
    read)
      mint_break_glass "${2:-${default_owner}}" "${bg_read_scope}" ""; echo ;;
    write)
      [ -n "${2:-}" ] || die "usage: openbao-github-creds break-glass write <owner>/<repo>"
      split_repo "$2"
      mint_break_glass "${owner}" "${bg_write_scope}" "${repo}"; echo ;;
    */*|*)
      # `break-glass <owner>` shorthand for read
      mint_break_glass "${1}" "${bg_read_scope}" ""; echo ;;
  esac
}

# --- repo-create: the one administration-scoped action ------------------------
#
# WHY THIS IS AN ACTION AND NOT A TOKEN VERB. `administration: write` is the
# permission that creates repositories — and also deletes them, transfers them,
# rewrites branch protection and flips visibility. Handing such a token to the
# caller the way `token write` does would put the single most destructive
# credential in this estate into a shell variable, a transcript, and an agent's
# environment, where it stays live for its full hour and is reusable for every
# other administration call. So this verb performs the creation itself: the
# token is minted, spent on exactly one API call, revoked, and never printed.
# Nothing the caller can capture carries administration rights.
#
# WHY THIS RUNS UNATTENDED, WITH NO TTY OR TYPED CONFIRMATION. The escalation
# already happened at credential-issuance time: OPENBAO_APPROLE_GITHUB_REPO_
# CREATE_ROLE_ID/_SECRET_ID is an operator-provisioned pair, scoped server-side
# by OpenBao's github secrets engine to permission map exactly
# {administration: write} (github/token/dryvist-repo-create) — the same
# boundary every other ambient tier (read, write) relies on. A second,
# interactive gate in front of an already-gated credential would only block
# the agents this tool exists to serve, not a human without the secret_id.
#
# Verified 2026-09-12 against GitHub's permissions reference: POST
# /orgs/{org}/repos requires repository permission `administration` = write and
# accepts an installation access token (IAT). The not-yet-existing repository
# cannot appear in a `repositories` list, so the narrowing axis here is
# PERMISSIONS, not repositories — installation-wide in breadth, one capability
# deep. Personal-account repositories are out of reach for an IAT entirely
# (POST /user/repos does not accept one); this verb is organisations only, and
# — per repo_create_set_for below — dryvist only, since that is the only
# repo-create set OpenBao currently has provisioned.

# Exactly one "owner/repo": both halves present, no third segment, nothing that
# is not a legal name character. Split out so --self-check can exercise it
# without a terminal or a network.
valid_repo_target() {
  case "$1" in
    *[!A-Za-z0-9._/-]*) return 1 ;;
    */*/*|/*|*/)        return 1 ;;
    */*)                return 0 ;;
    *)                  return 1 ;;
  esac
}

cmd_repo_create() {
  refuse_tty
  require_env
  local target="${1:-}" visibility="${2:-private}" owner repo private
  [ -n "${target}" ] \
    || die "usage: openbao-github-creds repo-create <owner>/<repo> [private|public]"
  valid_repo_target "${target}" \
    || die "expected exactly one <owner>/<repo>, got '${target}'. One repository per invocation; there is no batch form on purpose."
  case "${visibility}" in
    private) private=true ;;
    public)  private=false ;;
    *)       die "visibility must be 'private' or 'public', got '${visibility}'" ;;
  esac
  owner="${target%%/*}"
  repo="${target#*/}"

  do_repo_create "${owner}" "${repo}" "${private}" "${visibility}"
}

# Mints the administration-scoped token, spends it on exactly one
# repo-creation call, and revokes it. Split out of cmd_repo_create purely so
# this half — the part that actually touches a credential — can be driven
# directly in a test without going through refuse_tty/require_env.
do_repo_create() {
  local owner="$1" repo="$2" private="$3" visibility="$4"
  local body resp code url
  # mint_repo_create guarantees a non-empty token or dies (require_tok inside
  # it) — no separate check needed here.
  tok="$(mint_repo_create "${owner}")"
  # Spend it, then kill it. GitHub revokes the installation token the call was
  # made with, so the credential stops existing once this function returns
  # rather than living out its hour. Best-effort: a failed revoke must not turn
  # a successful creation into an error.
  #
  # `tok` is deliberately NOT `local`. Bash pops a function's locals the
  # moment it returns, but this EXIT trap doesn't fire until the whole
  # process exits — which, on the success path below, is after this function
  # has already returned. A `local tok` here left the trap referencing an
  # unbound variable on exactly that path (the only one where a real
  # administration token is ever minted and spent): under `set -u` the
  # expansion aborted before the trap's own command ran, so the DELETE never
  # happened and the token lived out its full ~1h TTL. Every error path
  # (403/404/422/die) was unaffected, because those call `exit` from within
  # this same function's still-live call frame — only the return-normally
  # path was silently unrevoked.
  # shellcheck disable=SC2317  # reached via the EXIT trap, not by fallthrough
  revoke() {
    curl -s -o /dev/null --max-time 10 -X DELETE \
      -H "Authorization: Bearer ${tok}" -H "Accept: application/vnd.github+json" \
      "https://api.github.com/installation/token" || true
  }
  trap revoke EXIT

  body="$(jq -cn --arg n "${repo}" --argjson p "${private}" '{name: $n, private: $p}')"
  resp="$(printf '%s' "${body}" \
    | curl -s --max-time 20 -w $'\n%{http_code}' -X POST \
        -H "Authorization: Bearer ${tok}" -H "Accept: application/vnd.github+json" \
        --data-binary @- "https://api.github.com/orgs/${owner}/repos")"
  code="${resp##*$'\n'}"
  resp="${resp%$'\n'*}"
  case "${code}" in
    201)
      url="$(jq -r '.html_url // empty' <<<"${resp}")"
      printf '%s\n' "${url:-https://github.com/${owner}/${repo}}"
      echo "$prefix created ${owner}/${repo} (${visibility}); administration token revoked." >&2
      ;;
    403)
      die "GitHub refused the creation (403). The App installation for '${owner}' most likely does not hold Administration: write — that grant is a one-time organisation-settings change and cannot be made from here. $(jq -r '.message // empty' <<<"${resp}")"
      ;;
    404)
      die "GitHub returned 404 for org '${owner}'. Either the organisation name is wrong, or '${owner}' is a personal account — an App installation token cannot create repositories on a personal account at all (POST /user/repos does not accept one)."
      ;;
    422)
      die "GitHub rejected the name (422) — usually '${repo}' already exists in ${owner}. $(jq -r '.message // empty' <<<"${resp}")"
      ;;
    *)
      die "repository creation failed (HTTP ${code}): $(jq -r '.message // empty' <<<"${resp}")"
      ;;
  esac
}

lock_path() { echo "github/token"; }  # documented anchor; real path built inline

# CAS-acquire the per-repo write lease. Refuses if another live holder owns it.
lock_acquire() {
  local iid="$1" repo="$2" bao_tok prefix data_url meta_url cur ver holder me now
  me="$(lock_holder)"
  prefix="$(write_login_prefix_for "${repo}")"
  bao_tok="$(bao_login "${prefix}")"
  require_tok "${bao_tok}" "${prefix}"
  data_url="${bao_addr}/v1/secret/data/locks/github-write/${iid}/${repo}"
  meta_url="${bao_addr}/v1/secret/metadata/locks/github-write/${iid}/${repo}"
  # Server-side deadman: each lock version self-deletes, freeing a crashed holder.
  jq -cn --arg ttl "${OPENBAO_GH_LOCK_TTL:-15m}" '{delete_version_after: $ttl}' \
    | curl -sf --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" --data-binary @- \
        "${meta_url}" >/dev/null \
    || true
  cur="$(curl -sf --max-time 10 -H "X-Vault-Token: ${bao_tok}" "${data_url}" 2>/dev/null || echo '{}')"
  holder="$(jq -r '.data.data.holder // empty' <<<"${cur}")"
  ver="$(jq -r '.data.metadata.version // empty' <<<"${cur}")"
  if [ -n "${holder}" ] && [ "${holder}" != "${me}" ]; then
    die "repo ${repo} is write-leased by '${holder}' — release it or wait for the lease to expire"
  fi
  # The deadman deletes the version's DATA but leaves the key's METADATA behind,
  # so an expired lease reads back as a 404 while current_version stays at N.
  # Defaulting ver to 0 there sends cas=0, which KV-v2 defines as "write only if
  # this key has never existed" — permanently rejected with HTTP 400 once
  # metadata exists. The lock then deadlocks forever and reports it as a race
  # against another agent, which is exactly the wrong thing to go looking for.
  # On a data 404, read current_version from the metadata instead.
  if [ -z "${ver}" ]; then
    ver="$(curl -sf --max-time 10 -H "X-Vault-Token: ${bao_tok}" "${meta_url}" 2>/dev/null \
             | jq -r '.data.current_version // 0')"
    ver="${ver:-0}"
  fi
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local acq
  acq="$(jq -cn --arg h "${me}" --arg t "${now}" --argjson v "${ver}" \
        '{options:{cas:$v}, data:{holder:$h, acquired_at:$t}}' \
    | curl -s --max-time 10 -o /dev/null -w '%{http_code}' -X POST \
        -H "X-Vault-Token: ${bao_tok}" --data-binary @- \
        "${data_url}")"
  # A 400 here is a genuine CAS mismatch (someone else wrote between our read and
  # our write). Name both possibilities rather than only the race — the expired
  # -lease case above looked identical and cost hours of chasing a phantom agent.
  [ "${acq}" = "200" ] \
    || die "could not acquire the write lease for ${repo} (CAS rejected at version ${ver}; HTTP ${acq})"
}

lock_release() {
  local iid="$1" repo="$2" bao_tok ap_prefix meta_url
  ap_prefix="$(write_login_prefix_for "${repo}")"
  bao_tok="$(bao_login "${ap_prefix}")"
  require_tok "${bao_tok}" "${ap_prefix}"
  meta_url="${bao_addr}/v1/secret/metadata/locks/github-write/${iid}/${repo}"
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

# Shell for the caller to eval: the claim is recorded and released first so a
# failed mint still frees the lease, and the token is minted by the caller's own
# command substitution rather than by this process. No credential passes through
# this script's stdout, so output that reaches a transcript instead of an eval
# carries nothing to leak. refuse_tty cannot cover that case: a pipe into a
# transcript is indistinguishable from a pipe into eval.
claim_exports() {
  printf 'export OPENBAO_GH_CLAIM=%q;\n' "$1"
  printf 'trap %q EXIT;\n' "openbao-github-creds release >/dev/null 2>&1 || true"
  # The substitution must reach the caller unexpanded — it is what moves the
  # mint out of this process — so the single quotes are deliberate.
  # shellcheck disable=SC2016
  printf 'export GITHUB_TOKEN="$(openbao-github-creds token write %q)";\n' "$1"
}

cmd_claim() {
  refuse_tty "$@"
  local owner repo iid
  require_env
  [ -n "${1:-}" ] || die "usage: openbao-github-creds claim <owner>/<repo>"
  split_repo "$1"
  iid="$(installation_id_for "${owner}")"
  [ -n "${iid}" ] || die "no installation id for owner '${owner}'"
  lock_acquire "${iid}" "${repo}"
  claim_exports "${owner}/${repo}"
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
  refuse_tty "$@"
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
  # The guard must never block the CORRECT use. Every real caller
  # captures stdout, so stdout is a pipe and refuse_tty must return 0.
  # A regression here would break git, gh and every wrapper at once,
  # which is far worse than the leak the guard prevents.
  refuse_tty >/dev/null 2>&1 \
    || { echo "self-check FAIL: refuse_tty blocked a non-terminal (captured) call"; return 1; }
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
  # break-glass scopes must be valid JSON objects, minimal, and never grant admin.
  if ! jq -e . >/dev/null 2>&1 <<<"${bg_read_scope}"; then
    echo "self-check FAIL: break-glass read scope not valid JSON"; return 1
  fi
  if ! jq -e . >/dev/null 2>&1 <<<"${bg_write_scope}"; then
    echo "self-check FAIL: break-glass write scope not valid JSON"; return 1
  fi
  if [ "$(jq -r '.pull_requests' <<<"${bg_write_scope}")" != "write" ]; then
    echo "self-check FAIL: break-glass write scope lacks pull_requests:write"; return 1
  fi
  # The EVERYDAY paths must never grant administration. That assertion predates
  # repo-create and is not weakened by it: repo-create does not hand its token
  # to anyone, so these two remain the only scopes a caller can ever hold.
  if [ "$(jq -r 'has("administration")' <<<"${bg_write_scope}")" != "false" ]; then
    echo "self-check FAIL: break-glass write scope must never grant administration"; return 1
  fi
  if [ "$(jq -r 'has("administration")' <<<"${bg_read_scope}")" != "false" ]; then
    echo "self-check FAIL: break-glass read scope must never grant administration"; return 1
  fi
  self_check_repo_create || return 1
  self_check_write_realms || return 1
  self_check_lock_reacquire || return 1
  echo "self-check OK"
}

# Realm routing, exercised without a server. Both directions matter: a mapped
# repository must reach its own identity, and — just as important — everything
# else must keep reaching the default one, because that fallback is what makes
# realms optional rather than a flag day.
self_check_write_realms() {
  local got
  # No realms configured at all: every repository uses the default identity.
  got="$(OPENBAO_GITHUB_WRITE_SCOPES="" write_login_prefix_for any-repo)"
  [ "${got}" = "GITHUB_WRITE" ] \
    || { echo "self-check FAIL: unset realms routed to '${got}'"; return 1; }

  local scopes='{"realm-one":["mapped-repo"],"realm-two":["other-repo"]}'

  got="$(OPENBAO_GITHUB_WRITE_SCOPES="${scopes}" write_login_prefix_for mapped-repo)"
  [ "${got}" = "REALM_ONE" ] \
    || { echo "self-check FAIL: mapped repo routed to '${got}'"; return 1; }

  got="$(OPENBAO_GITHUB_WRITE_SCOPES="${scopes}" write_login_prefix_for unmapped-repo)"
  [ "${got}" = "GITHUB_WRITE" ] \
    || { echo "self-check FAIL: unmapped repo routed to '${got}'"; return 1; }

  # Exact membership, not substring: a realm holding "mapped-repo" must not
  # capture a differently-named repository that merely contains it.
  got="$(OPENBAO_GITHUB_WRITE_SCOPES="${scopes}" write_login_prefix_for mapped-repo-extra)"
  [ "${got}" = "GITHUB_WRITE" ] \
    || { echo "self-check FAIL: substring match captured '${got}'"; return 1; }

  # Malformed data must not silently route a realm repository to the shared
  # identity in a way that looks like success; it falls back, visibly.
  got="$(OPENBAO_GITHUB_WRITE_SCOPES="not json" write_login_prefix_for mapped-repo)"
  [ "${got}" = "GITHUB_WRITE" ] \
    || { echo "self-check FAIL: malformed realm data routed to '${got}'"; return 1; }
}

# repo-create: exercised without a server. Owner routing and target validation
# both run unconditionally; the AppRole-mint check below is the one
# live-adjacent piece, asserting the tier fails CLOSED rather than falling
# back to some other credential when its env pair is absent — no live mint
# attempted either way.
self_check_repo_create() {
  local got out
  got="$(repo_create_set_for dryvist)"
  [ "${got}" = "dryvist-repo-create" ] \
    || { echo "self-check FAIL: repo_create_set_for dryvist = '${got}'"; return 1; }

  if out="$(repo_create_set_for JacobPEvans-personal 2>&1)"; then
    echo "self-check FAIL: repo_create_set_for accepted a non-dryvist owner ('${out}')"; return 1
  fi

  # Target validation: one repo per invocation, and nothing that could smuggle
  # a second path segment or a shell/URL metacharacter into the API path.
  local t
  for t in dryvist/new-repo owner/a.b_c-d; do
    valid_repo_target "${t}" || { echo "self-check FAIL: rejected valid target '${t}'"; return 1; }
  done
  for t in "" bare-repo a/b/c /leading trailing/ "a b/c" "a/b;id" "a/b?x=1"; do
    if valid_repo_target "${t}"; then
      echo "self-check FAIL: accepted invalid target '${t}'"; return 1
    fi
  done

  if bao_login_configured GITHUB_REPO_CREATE; then
    echo "self-check SKIP: GITHUB_REPO_CREATE AppRole configured on this machine — not exercising a live mint"
    return 0
  fi
  # Not configured: mint_repo_create must die naming the missing env pair,
  # never silently mint from some other identity or return an empty token.
  if out="$(mint_repo_create dryvist 2>&1)"; then
    echo "self-check FAIL: mint_repo_create succeeded with no GITHUB_REPO_CREATE credential ('${out}')"; return 1
  fi
  case "${out}" in
    *OPENBAO_APPROLE_GITHUB_REPO_CREATE_ROLE_ID*OPENBAO_APPROLE_GITHUB_REPO_CREATE_SECRET_ID*) : ;;
    *) echo "self-check FAIL: missing-credential error didn't name the env pair: ${out}"; return 1 ;;
  esac
}

# A lease whose deadman fired must still be re-acquirable. The failure this
# guards against is silent and total: the key's metadata outlives the deleted
# version, so a cas derived from the (404) data read deadlocks the repo forever
# while reporting a race against another agent. Exercised on a throwaway key.
self_check_lock_reacquire() {
  local bao_tok base d m code ver
  # A SKIP is honest ONLY when this machine was never given the credential.
  # Ask that question directly, before attempting anything: it is the one case
  # where having no token is expected rather than a fault.
  if ! bao_login_configured GITHUB_WRITE; then
    echo "self-check SKIP: GITHUB_WRITE AppRole not configured on this machine"
    return 0
  fi
  # Past this point the credential EXISTS, so a login that fails is a fault,
  # not an absence. The previous form attached `|| ... return 0` to the login
  # itself, which both disabled errexit and rewrote the verdict: the run
  # printed an error, then "SKIP", then "self-check OK", and exited 0. A check
  # whose entire purpose is to notice an unusable credential must never answer
  # OK to one.
  bao_tok="$(bao_login GITHUB_WRITE)" \
    || { echo "self-check FAIL: GITHUB_WRITE is configured but its AppRole login failed"; return 1; }
  base="${bao_addr}/v1/secret"
  d="${base}/data/locks/github-write/147266792/zz-self-check"
  m="${base}/metadata/locks/github-write/147266792/zz-self-check"

  curl -s -o /dev/null --max-time 10 -X DELETE -H "X-Vault-Token: ${bao_tok}" "${m}"
  printf '%s' '{"options":{"cas":0},"data":{"holder":"self-check"}}' \
    | curl -s -o /dev/null --max-time 10 -X POST -H "X-Vault-Token: ${bao_tok}" --data-binary @- "${d}"
  # Delete the version's data but leave metadata: exactly what the deadman does.
  curl -s -o /dev/null --max-time 10 -X DELETE -H "X-Vault-Token: ${bao_tok}" "${d}"

  ver="$(curl -sf --max-time 10 -H "X-Vault-Token: ${bao_tok}" "${m}" 2>/dev/null \
           | jq -r '.data.current_version // 0')"
  code="$(jq -cn --argjson v "${ver:-0}" '{options:{cas:$v}, data:{holder:"self-check-2"}}' \
    | curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST \
        -H "X-Vault-Token: ${bao_tok}" --data-binary @- "${d}")"
  curl -s -o /dev/null --max-time 10 -X DELETE -H "X-Vault-Token: ${bao_tok}" "${m}"

  [ "${code}" = "200" ] \
    || { echo "self-check FAIL: expired lease not re-acquirable (cas=${ver} -> HTTP ${code})"; return 1; }
}

# Sourcing this file loads its functions without dispatching, so a unit test
# can exercise one in isolation. `return` only succeeds in a sourced shell.
(return 0 2>/dev/null) && return 0

case "${1:-}" in
  get)          cmd_get ;;
  store|erase)  exit 0 ;;
  claim)        cmd_claim "${2:-}" ;;
  release)      cmd_release "${2:-}" ;;
  token)        shift; cmd_token "$@" ;;
  break-glass)  shift; cmd_break_glass "$@" ;;
  repo-create)  shift; cmd_repo_create "$@" ;;
  --self-check) self_check ;;
  *) die "usage: openbao-github-creds {get|store|erase|claim <owner>/<repo>|release [<owner>/<repo>]|token [read|write] [<owner>[/<repo>]]|break-glass [read|write] [<owner>[/<repo>]]|repo-create <owner>/<repo> [private|public]|--self-check}" ;;
esac
