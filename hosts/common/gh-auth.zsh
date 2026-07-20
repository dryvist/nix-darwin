# Interactive GitHub credential helpers, backed by OpenBao.
# Sourced from hosts/common/zsh-macos.nix initContent (workstations only).
#
# Provides:
#   gh-read  [<owner>]        ambient read token for the whole installation
#   gh-claim [<owner>/<repo>] per-repo write lease + write token
#   gh-release                drop the lease early (it also auto-releases on exit)
#
# These replace the retired keychain PAT tier switches (gh-restricted /
# gh-dryvist / gh-admin / ...). Nothing is stored: every call mints a fresh
# ephemeral GitHub App installation token through openbao-github-creds.
#
# `git` needs none of this — the credential helper already mints per request.
# These exist only for `gh` and other tools that read GITHUB_TOKEN from the
# environment.
#
# Why functions and not a direnv/.envrc export: direnv caches its environment
# dump on disk, so exporting a token at .envrc load time would persist a
# credential to disk. Minting happens at call time, in the caller's shell, and
# lives only as long as that shell.
#
# Secret-zero (VAULT_ADDR, the AppRole ids, the installation ids) is ambient
# via `doppler run`, and Doppler's config is scoped to $GIT_HOME — so the mint
# runs from there in a subshell and the caller's working directory is
# irrelevant.

# owner/repo for the current repository, derived from the `origin` remote.
# Handles both transports: git@github.com:owner/repo.git and
# https://github.com/owner/repo.git
_gh_nwo() {
  local url
  url="$(git remote get-url origin 2>/dev/null)" || return 1
  [ -n "$url" ] || return 1
  case "$url" in
    *github.com[:/]*) ;;
    *) return 1 ;;
  esac
  printf '%s' "$url" | sed -E 's#^.*github\.com[:/]+##; s#\.git$##; s#/+$##'
}

# Resolve the argument, or fall back to the current repo. $1 is "owner" or
# "nwo" and decides whether the owner alone or the full owner/repo is wanted.
_gh_target() {
  local want="$1" given="$2" nwo
  if [ -n "$given" ]; then
    printf '%s' "$given"
    return 0
  fi
  if ! nwo="$(_gh_nwo)"; then
    echo "[gh-auth] ERROR not in a git repo with a github.com 'origin' remote — pass the target explicitly" >&2
    return 1
  fi
  # The dryvist -> JacobPEvans org rename is unfinished, so a bare
  # `JacobPEvans/...` remote could belong to either installation. Refuse to
  # guess rather than mint against the wrong one.
  case "$nwo" in
    JacobPEvans/*)
      echo "[gh-auth] ERROR 'origin' points at JacobPEvans/*, which is ambiguous between the dryvist and JacobPEvans-personal installations — pass the real owner explicitly" >&2
      return 1
      ;;
  esac
  case "$want" in
    owner) printf '%s' "${nwo%%/*}" ;;
    *)     printf '%s' "$nwo" ;;
  esac
}

# Ambient read token for every repo in the owner's installation.
gh-read() {
  local owner token
  owner="$(_gh_target owner "${1:-}")" || return 1
  token="$( cd "$GIT_HOME" && doppler run -- openbao-github-creds token read "$owner" )" || return 1
  if [ -z "$token" ]; then
    echo "[gh-auth] ERROR empty token returned for '$owner' — nothing exported" >&2
    return 1
  fi
  export GITHUB_TOKEN="$token"
  echo "[gh-auth] read token active for $owner (this shell only)" >&2
}

# Per-repo write lease + write token. The wrapper prints the export plus its own
# auto-release trap, so eval its output verbatim — do not re-implement the lease.
gh-claim() {
  local nwo out
  nwo="$(_gh_target nwo "${1:-}")" || return 1
  out="$( cd "$GIT_HOME" && doppler run -- openbao-github-creds claim "$nwo" )" || return 1
  if [ -z "$out" ]; then
    echo "[gh-auth] ERROR claim on '$nwo' produced nothing — lease not taken" >&2
    return 1
  fi
  eval "$out"
}

# Release a held write lease early. Exiting the shell does this anyway.
gh-release() {
  ( cd "$GIT_HOME" && doppler run -- openbao-github-creds release "${1:-}" )
  unset GITHUB_TOKEN
}
