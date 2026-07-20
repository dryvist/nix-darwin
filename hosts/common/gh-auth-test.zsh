#!/usr/bin/env zsh
# Self-check for hosts/common/gh-auth.zsh remote-URL parsing.
# Run: zsh hosts/common/gh-auth-test.zsh
#
# Only _gh_nwo is exercised — it is the one piece of non-trivial logic that can
# silently mint against the wrong installation if it mis-parses. The minting
# functions are thin wrappers over openbao-github-creds and are covered by that
# script's own --self-check.
set -uo pipefail

source "${0:A:h}/gh-auth.zsh"

# Stub `git` so _gh_nwo reads the case under test instead of the real remote.
typeset -g STUB_URL=''
git() {
  if [[ "$1" == remote && "$2" == get-url ]]; then
    [[ -n "$STUB_URL" ]] || return 1
    printf '%s\n' "$STUB_URL"
    return 0
  fi
  command git "$@"
}

fail=0
check() {
  STUB_URL="$1"
  local want="$2" got
  got="$(_gh_nwo)" || got='<refused>'
  if [[ "$got" == "$want" ]]; then
    print "ok    ${1:-<empty>} -> $got"
  else
    print "FAIL  ${1:-<empty>} -> got '$got', want '$want'"
    fail=1
  fi
}

check 'git@github.com:dryvist/nix-darwin.git'          'dryvist/nix-darwin'
check 'https://github.com/dryvist/nix-darwin.git'      'dryvist/nix-darwin'
check 'https://github.com/dryvist/nix-darwin'          'dryvist/nix-darwin'
check 'ssh://git@github.com/dryvist/nix-darwin.git'    'dryvist/nix-darwin'
check 'git@github.com:JacobPEvans-personal/thing.git'  'JacobPEvans-personal/thing'
check 'https://gitlab.com/dryvist/other.git'           '<refused>'
check ''                                               '<refused>'

if (( fail == 0 )); then
  print "\nall gh-auth parsing checks passed"
else
  print "\nfailures above"
  exit 1
fi
