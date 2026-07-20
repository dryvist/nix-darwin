# Interactive GitHub credential helpers, backed by OpenBao.
# Sourced from hosts/common/zsh-macos.nix initContent (workstations only).
#
#   gh-read [<owner>]   ambient read token for the whole installation
#   gh-claim            per-repo write lease + token for the current repo
#   gh-release          drop the lease early
#
# These replace the retired keychain PAT tier switches. Nothing is stored: each
# call mints a fresh ephemeral GitHub App installation token.
#
# `git` needs none of this — its credential helper already mints per request.
# These exist for `gh` and anything else that reads GITHUB_TOKEN from the env.
#
# Not a direnv/.envrc export: direnv caches its environment dump on disk, so
# exporting there would persist a credential. Minting happens at call time.
#
# gh-claim and gh-release are ALIASES, not functions, on purpose. The wrapper
# emits `trap ... EXIT` alongside its exports, and zsh scopes a trap set inside
# a function to that function — eval'ing it in a function body would release the
# lease the instant the function returned, leaving a write token with no lease.
# An alias expands in the caller's context, so the trap lands where it belongs.

# The wrapper, run from $GIT_HOME so doppler's scoped config resolves whatever
# the caller's cwd is. Every helper below goes through this.
_gh() { ( cd "$GIT_HOME" && doppler run -- openbao-github-creds "$@" ); }

# owner/repo (want=nwo) or owner (want=owner) for the current repo, from the
# `origin` remote. Handles git@github.com:o/r.git and https://github.com/o/r.git
_gh_target() {
  local url nwo
  url="$(git remote get-url origin 2>/dev/null)"
  nwo="${${url##*github.com[:/]}%.git}"
  if [[ -z "$url" || "$url" != *github.com[:/]* ]]; then
    print -u2 "[gh-auth] ERROR no github.com 'origin' remote here"
    return 1
  fi
  # The dryvist -> JacobPEvans org rename is unfinished, and the wrapper treats
  # every non-dryvist owner as the personal installation — so a bare
  # `JacobPEvans` would silently mint against the wrong one.
  if [[ "$nwo" == JacobPEvans/* ]]; then
    print -u2 "[gh-auth] ERROR 'JacobPEvans' is ambiguous between the dryvist and JacobPEvans-personal installations"
    return 1
  fi
  [[ "$1" == owner ]] && print -r -- "${nwo%%/*}" || print -r -- "$nwo"
}

gh-read() {
  local owner token
  owner="${1:-$(_gh_target owner)}" || return 1
  token="$(_gh token read "$owner")" || return 1
  if [[ -z "$token" ]]; then
    print -u2 "[gh-auth] ERROR empty token for '$owner' — nothing exported"
    return 1
  fi
  export GITHUB_TOKEN="$token"
  print -u2 "[gh-auth] read token active for $owner (this shell only)"
}

alias gh-claim='eval "$(_gh claim "$(_gh_target nwo)")"'
alias gh-release='eval "$(_gh release)"'
