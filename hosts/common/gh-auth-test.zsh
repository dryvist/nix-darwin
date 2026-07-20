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
