#!/usr/bin/env bash
# Validate Package Freshness - Pre-commit Hook
#
# PURPOSE: Prevent committing flake.lock with outdated package versions
# SCOPE: Depth-1 only — checks direct inputs from .nodes.root.inputs, not transitive deps
# FAIL THRESHOLDS:
#   - Critical packages (nixpkgs, home-manager, ai-assistant-instructions): >30 days = FAIL
#   - All direct inputs: >90 days = FAIL
# EXEMPTIONS: Packages in EXEMPT_PACKAGES array skip age checks
#
# USAGE: Run as pre-commit hook or manually: ./scripts/validate-package-freshness.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration
CRITICAL_THRESHOLD_DAYS=30
GENERAL_THRESHOLD_DAYS=90
FLAKE_LOCK="flake.lock"

# Check if jq is available (must precede any jq usage)
if ! command -v jq &> /dev/null; then
  echo -e "${RED}✗ ERROR: jq is required but not installed${NC}"
  echo "Install: nix-shell -p jq or brew install jq"
  exit 1
fi

# Dynamically determine root's nixpkgs node name.
# When transitive deps (e.g. determinate) bring their own nixpkgs, Nix renames
# ours to nixpkgs_2, nixpkgs_3, etc. This resolves the actual node the root uses.
ROOT_NIXPKGS_NODE=$(jq -r '.nodes.root.inputs.nixpkgs // "nixpkgs"' "$FLAKE_LOCK" 2>/dev/null || echo "nixpkgs")

# Critical packages that must be <30 days old
CRITICAL_PACKAGES=(
  "$ROOT_NIXPKGS_NODE"
  "home-manager"
  "ai-assistant-instructions"
)

# Exempt packages (archived repos, intentional pins)
# Add packages here that should never trigger staleness failures
# Supports glob patterns: "prefix*" matches "prefix", "prefix_2", etc.
# Direct inputs are matched by their user-facing key; the transitive entries
# below (injected by Determinate/Nix, never depth-1 root inputs) are matched by
# node name in the transitive-exemption pass after the direct-input loop.
EXEMPT_PACKAGES=(
  "darwin"          # Pinned to nix-darwin-25.11 stable branch — infrequent backports
  "systems"         # nix-systems/default-darwin — rarely updated
  "pal-mcp-server"  # Upstream repo (BeehiveInnovations) — infrequent releases
  "flake-compat*"   # Compatibility shim and suffixed variants (flake-compat_2 etc)
  "nixpkgs_2"       # Determinate's transitive nixpkgs (Nix renames determinate's copy)
  "nix"             # DeterminateSystems/nix-src — pinned by determinate, not directly updatable
)

# Check if flake.lock exists
if [[ ! -f "$FLAKE_LOCK" ]]; then
  echo -e "${YELLOW}⚠  No flake.lock found, skipping freshness check${NC}"
  exit 0
fi

# Function: Extract lastModified timestamp from flake.lock
# SECURITY: Uses jq --arg to prevent package name from affecting jq expression
get_last_modified() {
  local package=$1
  jq -r --arg pkg "$package" '.nodes[$pkg].locked.lastModified // 0' "$FLAKE_LOCK"
}

# Function: Check if package matches any exemption pattern (supports glob patterns)
matches_exemption_pattern() {
  local element=$1
  shift
  local array=("$@")
  for pattern in "${array[@]}"; do
    # Use glob pattern matching (supports wildcards like "prefix*"); $pattern is
    # deliberately unquoted so the glob applies.
    # shellcheck disable=SC2053
    [[ "$element" == $pattern ]] && return 0
  done
  return 1
}

# Main validation loop
FAILED=0
WARNINGS=0
CURRENT_TIME=$(date +%s)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Package Freshness Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check critical packages first
echo "Checking CRITICAL packages (must be <$CRITICAL_THRESHOLD_DAYS days):"
while IFS= read -r package; do
  # Check if package exists in flake.lock
  # SECURITY: Uses jq --arg to prevent package name from affecting jq expression
  if ! jq -e --arg pkg "$package" '.nodes[$pkg]' "$FLAKE_LOCK" &> /dev/null; then
    echo -e "  ${YELLOW}⊘ SKIP${NC}: $package (not in flake.lock)"
    continue
  fi

  LAST_MOD=$(get_last_modified "$package")

  if [[ "$LAST_MOD" == "0" ]]; then
    echo -e "  ${YELLOW}⚠  WARN${NC}: $package (no lastModified field)"
    WARNINGS=$((WARNINGS + 1))
    continue
  fi

  DAYS_OLD=$(( (CURRENT_TIME - LAST_MOD) / 86400 ))

  if [[ $DAYS_OLD -gt $CRITICAL_THRESHOLD_DAYS ]]; then
    echo -e "  ${RED}✗ FAIL${NC}: $package is ${RED}$DAYS_OLD days${NC} old (threshold: $CRITICAL_THRESHOLD_DAYS days)"
    FAILED=$((FAILED + 1))
  else
    echo -e "  ${GREEN}✓ OK${NC}:   $package ($DAYS_OLD days old)"
  fi
done < <(printf '%s\n' "${CRITICAL_PACKAGES[@]}")

echo ""
echo "Checking DIRECT inputs (must be <$GENERAL_THRESHOLD_DAYS days):"

# Check direct inputs only (depth-1 from root)
# Use to_entries[] to get input key (user-facing name) and node name (for lastModified lookup)
while IFS=$'\t' read -r input_key node_name; do
  # Skip if already checked in critical packages (compare by node name since
  # CRITICAL_PACKAGES uses resolved node names like nixpkgs_3)
  if matches_exemption_pattern "$node_name" "${CRITICAL_PACKAGES[@]}"; then
    continue
  fi

  # Skip if in exempt list (compare by input key — user-facing name)
  if matches_exemption_pattern "$input_key" "${EXEMPT_PACKAGES[@]}"; then
    echo -e "  ${YELLOW}⊘ EXEMPT${NC}: $input_key (in exemption list)"
    continue
  fi

  LAST_MOD=$(get_last_modified "$node_name")

  if [[ "$LAST_MOD" == "0" ]]; then
    # No lastModified field (might be a flake input that follows another)
    continue
  fi

  DAYS_OLD=$(( (CURRENT_TIME - LAST_MOD) / 86400 ))

  if [[ $DAYS_OLD -gt $GENERAL_THRESHOLD_DAYS ]]; then
    echo -e "  ${RED}✗ FAIL${NC}: $input_key is ${RED}$DAYS_OLD days${NC} old (threshold: $GENERAL_THRESHOLD_DAYS days)"
    FAILED=$((FAILED + 1))
  elif [[ $DAYS_OLD -gt 60 ]]; then
    # Warn if approaching threshold
    echo -e "  ${YELLOW}⚠  WARN${NC}: $input_key is $DAYS_OLD days old (approaching threshold)"
    WARNINGS=$((WARNINGS + 1))
  else
    echo -e "  ${GREEN}✓ OK${NC}:   $input_key ($DAYS_OLD days old)"
  fi
done < <(jq -r '.nodes.root.inputs | to_entries[] | "\(.key)\t\(.value)"' "$FLAKE_LOCK")

# Determinate and Nix inject transitive nodes (nixpkgs_2, nix, flake-compat*)
# that are not depth-1 root inputs, so the loop above never visits them. Report
# the exempt ones so an intentional pin stays visible. This pass only reports;
# it never fails the run, preserving the depth-1 failure scoping above.
DIRECT_INPUTS=$(jq -r '.nodes.root.inputs[]? // empty' "$FLAKE_LOCK")
while IFS= read -r node_name; do
  [[ "$node_name" == "root" ]] && continue
  printf '%s\n' "$DIRECT_INPUTS" | grep -qxF "$node_name" && continue
  matches_exemption_pattern "$node_name" "${EXEMPT_PACKAGES[@]}" || continue
  echo -e "  ${YELLOW}⊘ EXEMPT${NC}: $node_name (in exemption list)"
done < <(jq -r '.nodes | keys[]' "$FLAKE_LOCK")

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}✗ VALIDATION FAILED${NC}: $FAILED package(s) exceed staleness threshold"
  echo ""
  echo "To fix outdated packages:"
  echo "  1. Update flake inputs: nix flake update"
  echo "  2. Or update specific input: nix flake update <package>"
  echo "  3. Review changes: nix flake metadata"
  echo "  4. Test rebuild: darwin-rebuild switch --flake ."
  echo ""
  echo "To exempt a package (intentional pin):"
  echo "  Add to EXEMPT_PACKAGES array in scripts/validate-package-freshness.sh"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}⚠  PASSED WITH WARNINGS${NC}: $WARNINGS package(s) approaching threshold"
  exit 0
else
  echo -e "${GREEN}✓ ALL PACKAGES FRESH${NC}: All packages within acceptable age ranges"
  exit 0
fi
