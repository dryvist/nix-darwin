#!/usr/bin/env bash
# check-closure-health.sh — the one closure check nix has no native command for.
#
# Reporting and diffing are NOT here, because nix already does both and the
# workflow calls them directly:
#
#   nix path-info --closure-size --human-readable --recursive  # sizes
#   nix store diff-closures <base> <new>                       # what a PR added
#
# What nix has no answer for is a derivation present TWICE in one closure. That
# is the signature of an input pinning its own nixpkgs instead of following the
# root: two full instances materialise and everything in the overlap is built or
# fetched twice — measured here at roughly a gigabyte for llvm, clang and the
# Apple SDK. It produces a perfectly valid closure, so no evaluation check sees
# it, and `diff-closures` cannot either: it compares two closures rather than
# looking inside one.
#
# Checked before writing this: `nix path-info`/`nix store` subcommands,
# DeterminateSystems' flake-checker (root nixpkgs branch/age/owner only — not
# duplicate or non-following inputs), and nixpkgs' nix-tree, nix-du, nix-diff
# and nix-visualize (all interactive or diagnostic, none enforcing). No native
# path exists, so this covers only that gap.
#
# Usage: check-closure-health.sh <store-path-or-result-link>
#   DUPLICATE_FLOOR_MB  ignore duplicates smaller than this (default 64)
#   DUPLICATE_BASELINE  duplicates already known and tracked (default 5)
#
# The baseline is a RATCHET, set at what is true today so the next regression
# fails while existing debt stays visible. Raising it to make a red build green
# is the one change this script exists to prevent.

set -euo pipefail

target="${1:?usage: check-closure-health.sh <store-path-or-result-link>}"
dup_floor_mb="${DUPLICATE_FLOOR_MB:-64}"
dup_baseline="${DUPLICATE_BASELINE:-5}"

if [ ! -e "$target" ]; then
  echo "check-closure-health: no such path: $target" >&2
  exit 1
fi

# Resolve to an absolute path first. A bare relative name like `result-hm` is
# parsed by nix as a FLAKE REFERENCE, not a path, and fails with "cannot find
# flake" — which reads like a broken checkout rather than a quoting bug. CI
# passes exactly that shape.
target=$(cd "$(dirname "$target")" && printf '%s/%s' "$(pwd)" "$(basename "$target")")

# Same derivation name at two or more store paths = two instances in one closure.
dups=$(nix path-info --recursive --size "$target" |
  awk -v floor=$((dup_floor_mb * 1048576)) '$2 >= floor {print $1}' |
  sed -E 's@/nix/store/[a-z0-9]{32}-@@' |
  sort | uniq -c | awk '$1 > 1 {print $1"\t"$2}' | sort -rn)

if [ -z "$dups" ]; then
  echo "No duplicated derivations over ${dup_floor_mb} MB."
  [ "$dup_baseline" -gt 0 ] && echo "::notice::DUPLICATE_BASELINE can drop to 0."
  exit 0
fi

echo "Duplicated derivations (same name, multiple store paths):"
echo "$dups"
dup_count=$(printf '%s\n' "$dups" | wc -l | tr -d ' ')

if [ "$dup_count" -gt "$dup_baseline" ]; then
  echo "::error::duplicated derivations rose to ${dup_count}, above the ${dup_baseline} already known. Something newly pins its own nixpkgs instead of following the root — check flake.lock for an added nixpkgs revision. Fix the input rather than raising DUPLICATE_BASELINE." >&2
  exit 1
fi

# Report the debt on success too: an "OK" that hides known duplicates is how a
# baseline meant to be temporary becomes permanent.
echo "::notice::${dup_count} duplicated derivation(s) at the tracked baseline of ${dup_baseline} — still debt, just not new."
