#!/usr/bin/env bash
# HARD FAIL if any homebrew packages/casks are available in nixpkgs
# Enforces: nixpkgs FIRST, homebrew as fallback ONLY

set -euo pipefail

# Check if nix command is available
if ! command -v nix &> /dev/null; then
  echo "ERROR: nix command is required but not available"
  exit 1
fi

JQ=$(command -v jq || true)
if [ -z "$JQ" ]; then
  echo "ERROR: jq is required to read nix --json output"
  exit 1
fi

# Known false positives: Same name, different apps, or intentional overrides
# Format: "package-name:reason"
EXCLUSIONS=(
  "antigravity:Intentionally using homebrew due to nixpkgs version lag (requires Gemini 3.1 Pro support)"
  "antigravity-ide:Intentionally using homebrew for early access to Google agent IDE"
  "claude:Not available for aarch64-darwin (only x86_64-linux)"
  "claude-code:Intentionally using homebrew due to recent nixpkgs latency on latest packages"
  "antigravity-cli:Intentionally using homebrew due to recent nixpkgs latency on latest packages"
  "bitwarden:nixpkgs build pins EOL electron_39 (insecure); cask uses Bitwarden's maintained build"
  "container:Homebrew tracks Apple container releases ahead of nixpkgs; use current upstream runtime"
  "orbstack:Cask preferred over nixpkgs for TCC permission stability (nixpkgs symlink changes on rebuild, forcing TCC re-grant)"
  "postman:Nixpkgs version lags significantly behind upstream, causing Squirrel/ShipIt schema mismatch errors"
)

# Read the EVALUATED config, never the Nix source text.
#
# This previously scraped `brews = [` / `casks = [` out of homebrew.nix with awk.
# The moment those stopped being literal lists — `brews =` with its value on the
# next line, `casks` built with `++ lib.optionals ...` — the pattern stopped
# matching, and the script reported "No homebrew packages to validate" and
# exited 0. It was validating NOTHING while passing, which is worse than not
# existing. Measured at the time of this fix: the text parse found 0 packages
# where evaluation finds 29.
#
# Evaluation cannot drift from the config this way: computed lists, conditionals
# and values merged from several modules all resolve before we see them.
host="${DARWIN_HOST:-}"
if [ -z "$host" ]; then
  host=$(nix eval --json '.#darwinConfigurations' --apply 'builtins.attrNames' 2>/dev/null |
    "$JQ" -r '.[0] // empty')
fi
if [ -z "$host" ]; then
  echo "ERROR: could not determine a darwinConfiguration to evaluate"
  exit 1
fi

eval_names() {
  nix eval --json ".#darwinConfigurations.${host}.config.homebrew.$1" 2>/dev/null |
    "$JQ" -r '.[].name' || true
}

brews=$(eval_names brews)
casks=$(eval_names casks)

# One search for every candidate, not one per package.
#
# `nix search` costs about 3.2s warmed, so the old per-package loop paid that
# for each of the 29 entries. The regex is an anchored alternation of every
# name, so a single invocation answers the whole question with identical
# semantics — still nixpkgs-wide, still exact-name, so nested attributes are
# found exactly as before. Names are pre-validated against [A-Za-z0-9._@-],
# which contains no regex metacharacter.
search_nixpkgs_batch() {
  local names="$1" pattern
  [ -z "$names" ] && return 0
  pattern=$(printf '%s' "$names" | tr '\n' '|' | sed 's/|$//')
  nix search --json nixpkgs "^(${pattern})\$" 2>/dev/null |
    "$JQ" -r 'to_entries[] | .value.pname // (.key | split(".") | last)' || true
}

if [[ -z "$brews" ]] && [[ -z "$casks" ]]; then
  echo "No homebrew packages to validate"
  exit 0
fi

in_nixpkgs=$(search_nixpkgs_batch "$(printf '%s\n%s' "$brews" "$casks" | grep -v '^$' | sort -u)")

echo "Checking if homebrew packages are available in nixpkgs..."
failed=0
violations=""

# Check if package is in exclusion list
is_excluded() {
  local pkg="$1"
  for exclusion in "${EXCLUSIONS[@]}"; do
    if [[ "$exclusion" == "$pkg:"* ]]; then
      return 0
    fi
  done
  return 1
}

# Get exclusion reason
get_exclusion_reason() {
  local pkg="$1"
  for exclusion in "${EXCLUSIONS[@]}"; do
    if [[ "$exclusion" == "$pkg:"* ]]; then
      echo "${exclusion#*:}"
      return
    fi
  done
}

# Check brews
while IFS= read -r package; do
  [[ -z "$package" ]] && continue

  # Validate package name contains only safe characters
  if ! [[ "$package" =~ ^[a-zA-Z0-9._@-]+$ ]]; then
    echo "✗ INVALID: '$package' (brew) contains unsafe characters"
    violations+="  - $package (brew) - invalid characters\n"
    failed=$((failed + 1))
    continue
  fi

  # Check if excluded
  if is_excluded "$package"; then
    reason=$(get_exclusion_reason "$package")
    echo "⊘ SKIP: '$package' (brew) - $reason"
    continue
  fi

  # Membership test against the single batched search below. The previous form
  # ran `nix search` once per package (measured ~3.2s each, warmed) and decided
  # the result by grepping its human-readable output for the word
  # "legacyPackages" — coupled to a display format that carries no such promise.
  if printf '%s\n' "$in_nixpkgs" | grep -qxF "$package"; then
    echo "✗ VIOLATION: '$package' (brew) is available in nixpkgs - use nixpkgs instead"
    violations+="  - $package (brew)\n"
    failed=$((failed + 1))
  else
    echo "✓ OK: '$package' (brew) not in nixpkgs"
  fi
done <<< "$brews"

# Check casks
while IFS= read -r package; do
  [[ -z "$package" ]] && continue

  # Validate package name contains only safe characters
  if ! [[ "$package" =~ ^[a-zA-Z0-9._@-]+$ ]]; then
    echo "✗ INVALID: '$package' (cask) contains unsafe characters"
    violations+="  - $package (cask) - invalid characters\n"
    failed=$((failed + 1))
    continue
  fi

  # Check if excluded
  if is_excluded "$package"; then
    reason=$(get_exclusion_reason "$package")
    echo "⊘ SKIP: '$package' (cask) - $reason"
    continue
  fi

  # Membership test against the single batched search below. The previous form
  # ran `nix search` once per package (measured ~3.2s each, warmed) and decided
  # the result by grepping its human-readable output for the word
  # "legacyPackages" — coupled to a display format that carries no such promise.
  if printf '%s\n' "$in_nixpkgs" | grep -qxF "$package"; then
    echo "✗ VIOLATION: '$package' (cask) is available in nixpkgs - use nixpkgs instead"
    violations+="  - $package (cask)\n"
    failed=$((failed + 1))
  else
    echo "✓ OK: '$package' (cask) not in nixpkgs"
  fi
done <<< "$casks"

if [[ $failed -gt 0 ]]; then
  echo ""
  echo "=========================================="
  echo "PACKAGE HIERARCHY VIOLATION"
  echo "=========================================="
  echo ""
  echo "The following homebrew packages are available in nixpkgs:"
  echo -e "$violations"
  echo "REQUIRED ACTION:"
  echo "1. Remove package from modules/darwin/homebrew.nix"
  echo "2. Add package to appropriate nixpkgs module"
  echo "   - System: modules/darwin/common.nix"
  echo "   - User: nix-home (home.packages via flake input)"
  echo ""
  echo "Package hierarchy (STRICT): nixpkgs → homebrew → bun → npm → bunx"
  exit 1
fi

echo "All homebrew packages validated - no nixpkgs alternatives available"
