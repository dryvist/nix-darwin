#!/usr/bin/env zsh
# Self-check for gh-auth.zsh remote parsing — the one bit that can silently
# mint against the wrong installation. Run: zsh hosts/common/gh-auth-test.zsh
source "${0:A:h}/gh-auth.zsh"

git() { [[ "$1 $2" == "remote get-url" ]] && { [[ -n "$URL" ]] && print -r -- "$URL" } }

fail=0
for case in \
  'git@github.com:dryvist/nix-darwin.git|nwo|dryvist/nix-darwin' \
  'https://github.com/dryvist/nix-darwin.git|nwo|dryvist/nix-darwin' \
  'https://github.com/dryvist/nix-darwin|nwo|dryvist/nix-darwin' \
  'ssh://git@github.com/dryvist/nix-darwin.git|nwo|dryvist/nix-darwin' \
  'git@github.com:dryvist/nix-darwin.git|owner|dryvist' \
  'git@github.com:JacobPEvans-personal/x.git|nwo|JacobPEvans-personal/x' \
  'git@github.com:JacobPEvans/x.git|nwo|<refused>' \
  'https://gitlab.com/dryvist/x.git|nwo|<refused>' \
  '|nwo|<refused>'
do
  URL="${case%%|*}" want="${case##*|}" arg="${${case#*|}%|*}"
  got="$(_gh_target "$arg" 2>/dev/null)" || got='<refused>'
  [[ "$got" == "$want" ]] && print "ok    ${URL:-<empty>} ($arg) -> $got" \
    || { print "FAIL  ${URL:-<empty>} ($arg) -> got '$got', want '$want'"; fail=1 }
done

(( fail )) && exit 1
print "\nall gh-auth parsing checks passed"

# --- gh wrapper: minting, caching, and the no-fallback rule -----------------
# The wrapper is the thing standing between `gh` and a stored credential, so
# assert it mints once, reuses the cache, re-mints after expiry, defers to an
# explicit token, and never silently proceeds when minting fails.
print "\n-- gh wrapper --"
URL='git@github.com:dryvist/nix-darwin.git'
# The mint itself must be read via $( ... ), so its side effects land in a
# subshell and a counter here cannot see them. The token VALUE is the honest
# signal instead: an unchanged value means the cache was used, a new one means
# a fresh mint.
mints=0
_gh() { [[ "$1 $2" == "token read" ]] && { mints=$(( $(<$MINTF) + 1 )); print -n $mints >! $MINTF; print -r -- "ghs_tok_${mints}" } }
MINTF="${TMPDIR:-/tmp}/gh-auth-test-mints.$$"; print -n 0 >! $MINTF
trap 'rm -f $MINTF' EXIT
# Records into a global rather than printing: capturing gh's output with $(...)
# would run the wrapper in a subshell, where the mint counter and the token
# cache it is supposed to populate both die on return.
command() { shift; LAST_OUT="TOKEN=${GITHUB_TOKEN:-<none>} ARGS=$*" }

chk() { # want, got, label
  [[ "$2" == "$1" ]] && print "ok    $3" || { print "FAIL  $3 -> got '$2', want '$1'"; fail=1 }
}

_GH_TOK= _GH_TOK_OWNER= _GH_TOK_EXP=0
gh pr list; chk 'TOKEN=ghs_tok_1 ARGS=pr list' "$LAST_OUT" 'first call mints'
gh pr view; chk 'TOKEN=ghs_tok_1 ARGS=pr view' "$LAST_OUT" 'second call reuses the cache'
chk 1 "$(<$MINTF)" 'exactly one mint for two calls'

_GH_TOK_EXP=0  # force expiry
gh pr list; chk 'TOKEN=ghs_tok_2 ARGS=pr list' "$LAST_OUT" 're-mints once expired'
chk 2 "$(<$MINTF)" 'expiry caused exactly one more mint'

GITHUB_TOKEN=explicit gh pr list
chk 'TOKEN=explicit ARGS=pr list' "$LAST_OUT" 'explicit token wins'
chk 2 "$(<$MINTF)" 'explicit token mints nothing'

_GH_TOK= _GH_TOK_OWNER= _GH_TOK_EXP=0
_gh() { return 1 }
gh pr list >/dev/null 2>&1
chk 1 "$?" 'mint failure fails closed (no stored-credential fallback)'

(( fail )) && exit 1
print "\nall gh-auth checks passed"
