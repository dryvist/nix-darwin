#!/usr/bin/env bash
# check-closure-health.sh — Assert the built closure stays small and unduplicated.
#
# CI wall time on this repo is dominated by closure size, not by evaluation. Two
# regressions have recurred here, both invisible until a build ran long:
#
#   1. A dependency lands twice. When an input pins its own nixpkgs instead of
#      following the root, every toolchain in the overlap materialises twice —
#      measured at ~1G for llvm + clang + apple-sdk alone. Nothing fails; the
#      build just gets slower and the cache tarball gets fatter.
#   2. A large opaque payload enters the closure. These substitute from nowhere
#      public, so every cold run refetches the whole thing.
#
# Neither is caught by evaluation checks, because both produce a perfectly valid
# closure. They are only visible by measuring one. This script measures.
#
# If you are reading this because the check failed: raising the budget is almost
# never the fix. Find what grew, or what got duplicated.
#
# Usage: check-closure-health.sh <store-path-or-result-link>
#   CLOSURE_BUDGET_MB   total closure ceiling (default 14336 = 14G)
#   DUPLICATE_FLOOR_MB  ignore duplicate pairs smaller than this (default 64)

set -euo pipefail

target="${1:?usage: check-closure-health.sh <store-path-or-result-link>}"
budget_mb="${CLOSURE_BUDGET_MB:-14336}"
dup_floor_mb="${DUPLICATE_FLOOR_MB:-64}"

if [ ! -e "$target" ]; then
  echo "check-closure-health: no such path: $target" >&2
  exit 1
fi

fail=0
die() {
  echo "::error::$*" >&2
  fail=1
}

sizes=$(mktemp)
trap 'rm -f "$sizes"' EXIT
nix path-info -rs "$target" 2>/dev/null | sort -k2 -nr >"$sizes"

if [ ! -s "$sizes" ]; then
  echo "check-closure-health: nix path-info returned nothing for $target" >&2
  exit 1
fi

total_bytes=$(awk '{s+=$2} END {print s+0}' "$sizes")
total_mb=$((total_bytes / 1048576))
path_count=$(wc -l <"$sizes" | tr -d ' ')

# Always report, pass or fail. A build that comes in under budget still tells
# you where the weight is, and that is the number to watch drift on.
echo "::notice::Closure ${total_mb} MB across ${path_count} paths (budget ${budget_mb} MB)"
echo "Largest paths by own size:"
# Truncate inside awk, never with `head`. Under `set -o pipefail` a `head` that
# closes the pipe early SIGPIPEs the upstream stage and takes the whole script
# down mid-report — silently, with a zero-ish look to a casual reader.
awk 'NR <= 15 {printf "%8.1f MB  %s\n", $2 / 1048576, $1}' "$sizes" |
  sed -E 's@/nix/store/[a-z0-9]{32}-@@'

# Same derivation name at two or more store paths means two instances of it in
# one closure. Above the floor this is always worth a look: it is the signature
# of an input that pins its own nixpkgs rather than following the root.
echo "Duplicated derivations (same name, multiple store paths):"
dups=$(awk -v floor=$((dup_floor_mb * 1048576)) '$2 >= floor {print $1}' "$sizes" |
  sed -E 's@/nix/store/[a-z0-9]{32}-@@' |
  sort | uniq -c | awk '$1 > 1 {print $1"\t"$2}' | sort -rn)

if [ -n "$dups" ]; then
  echo "$dups"
  dup_count=$(printf '%s\n' "$dups" | wc -l | tr -d ' ')
  redundant=$(printf '%s\n' "$dups" | awk '{n += $1 - 1} END {print n+0}')
  die "closure carries ${dup_count} duplicated derivation(s) over ${dup_floor_mb} MB (${redundant} redundant copies). This is normally an input pinning its own nixpkgs instead of following the root — check flake.lock for more than one nixpkgs revision."
else
  echo "  none over ${dup_floor_mb} MB"
fi

if [ "$total_mb" -gt "$budget_mb" ]; then
  die "closure is ${total_mb} MB, over the ${budget_mb} MB budget. Every MB here is refetched or rebuilt on a cold run. Shrink the closure rather than raising the budget."
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "Closure health OK: ${total_mb} MB, no duplicates over ${dup_floor_mb} MB."
