#!/usr/bin/env bash
# HARD FAIL if any homebrew packages/casks are available in nixpkgs
# Enforces: nixpkgs FIRST, homebrew as fallback ONLY

set -euo pipefail

# Check if nix command is available
if ! command -v nix &> /dev/null; then
  echo "ERROR: nix command is required but not available"
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

HOMEBREW_FILE="modules/darwin/homebrew.nix"

if [[ ! -f "$HOMEBREW_FILE" ]]; then
  echo "ERROR: $HOMEBREW_FILE not found"
  exit 1
fi

# Extract brew packages (brews = [...])
brews=$(awk '
  /brews = \[/ {in_brews=1; next}
  /^[[:space:]]*\][[:space:]]*(;|$|\+\+)/ && in_brews {in_brews=0; next}
  in_brews && ! /^[[:space:]]*#/ {print}
' "$HOMEBREW_FILE" | grep '"' | sed 's/.*"\([^"]*\)".*/\1/' || true)

# Extract cask packages (casks = [...])
casks=$(awk '
  /casks = \[/ {in_casks=1; next}
  /^[[:space:]]*\][[:space:]]*(;|$|\+\+)/ && in_casks {in_casks=0; next}
  in_casks && ! /^[[:space:]]*#/ {print}
' "$HOMEBREW_FILE" | grep '"' | sed 's/.*"\([^"]*\)".*/\1/' || true)

if [[ -z "$brews" ]] && [[ -z "$casks" ]]; then
  echo "No homebrew packages to validate"
  exit 0
fi

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
    ((failed++))
    continue
  fi

  # Check if excluded
  if is_excluded "$package"; then
    reason=$(get_exclusion_reason "$package")
    echo "⊘ SKIP: '$package' (brew) - $reason"
    continue
  fi

  # Search nixpkgs (suppress warnings to stderr, check if any results)
  # Note: package is validated to contain only [a-zA-Z0-9._-] characters above, preventing injection
  if nix search nixpkgs "^${package}\$" 2>/dev/null | grep -q "legacyPackages"; then
    echo "✗ VIOLATION: '$package' (brew) is available in nixpkgs - use nixpkgs instead"
    violations+="  - $package (brew)\n"
    ((failed++))
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
    ((failed++))
    continue
  fi

  # Check if excluded
  if is_excluded "$package"; then
    reason=$(get_exclusion_reason "$package")
    echo "⊘ SKIP: '$package' (cask) - $reason"
    continue
  fi

  # Search nixpkgs (suppress warnings to stderr, check if any results)
  # Note: package is validated to contain only [a-zA-Z0-9._-] characters above, preventing injection
  if nix search nixpkgs "^${package}\$" 2>/dev/null | grep -q "legacyPackages"; then
    echo "✗ VIOLATION: '$package' (cask) is available in nixpkgs - use nixpkgs instead"
    violations+="  - $package (cask)\n"
    ((failed++))
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
