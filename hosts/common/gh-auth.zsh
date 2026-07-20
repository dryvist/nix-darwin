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

# --- gh itself -------------------------------------------------------------
# gh does NOT consult git's credential helper, so the git-side OpenBao cutover
# never covered it. Left alone, gh authenticates from whatever it has stored —
# which is how a standing PAT silently satisfied a `gh pr create` on a repo
# whose write claim OpenBao had just REFUSED. Requiring an explicit `gh-read`
# first would work, but "forgot to run it" is exactly the failure above, so the
# secure path has to be the default path.
#
# This wrapper mints a READ token on demand when the shell has no token yet.
# Writes are deliberately NOT auto-minted: a mutating gh call under a read token
# fails closed with 403, which is the signal to run `gh-claim` and take a lease
# for the one repo. Never silently widen a read into a write.
#
# The token is cached in a shell variable, never on disk (a disk cache is a
# stored credential), and re-minted well inside its lifetime.
zmodload -F zsh/datetime +p:EPOCHSECONDS 2>/dev/null
typeset -g _GH_TOK= _GH_TOK_OWNER= _GH_TOK_EXP=0

# Leaves the token in $_GH_TOK rather than printing it. Printing would force
# the caller into $( ... ), and a command substitution runs this in a subshell —
# where the cache it just populated dies on return, so every call would re-mint.
_gh_read_cached() {
  local owner="$1" now="${EPOCHSECONDS:-$(date +%s)}" token
  if [[ -n "$_GH_TOK" && "$owner" == "$_GH_TOK_OWNER" && "$now" -lt "$_GH_TOK_EXP" ]]; then
    return 0
  fi
  token="$(_gh token read "$owner")" || return 1
  [[ -n "$token" ]] || return 1
  _GH_TOK="$token"
  _GH_TOK_OWNER="$owner"
  # Server TTL is an hour; refresh at half that so a long-running command never
  # starts with a token that expires mid-flight.
  _GH_TOK_EXP=$(( now + 1800 ))
}

gh() {
  # An explicit token — gh-read, gh-claim, or a caller-supplied one — always wins.
  if [[ -n "$GITHUB_TOKEN" || -n "$GH_TOKEN" ]]; then
    command gh "$@"
    return
  fi
  local owner
  # Outside a repo there is no owner to infer; gh subcommands that need auth
  # will say so themselves rather than us guessing an installation.
  owner="$(_gh_target owner 2>/dev/null)" || { command gh "$@"; return; }
  if ! _gh_read_cached "$owner"; then
    print -u2 "[gh-auth] ERROR could not mint a read token for '$owner' — not falling back to a stored credential"
    return 1
  fi
  GITHUB_TOKEN="$_GH_TOK" command gh "$@"
}

alias gh-claim='eval "$(_gh claim "$(_gh_target nwo)")"'
alias gh-release='eval "$(_gh release)"'
