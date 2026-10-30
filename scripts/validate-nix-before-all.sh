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

policy=$(nix eval --json --file lib/homebrew-policy.nix) || {
  echo "ERROR: could not evaluate Homebrew channel policy" >&2
  exit 1
}
"$JQ" -e '.exceptions.brews | type == "object"' <<< "$policy" >/dev/null
"$JQ" -e '.exceptions.casks | type == "object"' <<< "$policy" >/dev/null

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
  host=$(nix eval --json '.#darwinConfigurations' --apply 'builtins.attrNames' |
    "$JQ" -r '.[0] // empty')
fi
if [ -z "$host" ]; then
  echo "ERROR: could not determine a darwinConfiguration to evaluate"
  exit 1
fi

# An evaluation that FAILS and one that succeeds with an empty list are not the
# same answer, and the earlier form could not tell them apart: it discarded
# stderr and ended with `|| true`, so a failed eval produced empty output, both
# lists came back empty, and the script printed "No homebrew packages to
# validate" and exited 0. That is the same validating-nothing-while-passing
# failure the comment above describes, reintroduced one line below it.
#
# So: let the error through, and refuse to answer at all when it happens. An
# empty-but-successful list is still a legitimate no-op and still exits 0.
eval_names() {
  local out
  if ! out=$(nix eval --json ".#darwinConfigurations.${host}.config.homebrew.$1"); then
    echo "ERROR: could not evaluate homebrew.$1 for '${host}' — refusing to report a clean run" >&2
    return 1
  fi
  printf '%s' "$out" | "$JQ" -r '.[].name'
}

brews=$(eval_names brews)
casks=$(eval_names casks)

# One search for every candidate, not one per package.
#
# `nix search` costs about 3.2s warmed, so the old per-package loop paid that
# for each of the 29 entries. The regex is an anchored alternation of every
# name. Match complete derivation names and attribute-path suffixes, then apply
# exact filtering below. Names are pre-validated, and periods are escaped.
search_nixpkgs_batch() {
  local names="$1" pattern
  [ -z "$names" ] && return 0
  pattern=$(printf '%s' "$names" | sed 's/\./\\./g' | tr '\n' '|' | sed 's/|$//')
  nix search --json --inputs-from . --system aarch64-darwin nixpkgs "(^|\\.)(${pattern})\$"
}

if [[ -z "$brews" ]] && [[ -z "$casks" ]]; then
  echo "No homebrew packages to validate"
  exit 0
fi

all_names=$(printf '%s\n%s' "$brews" "$casks" | grep -v '^$' | sort -u)
if printf '%s\n' "$all_names" | grep -qvE '^[a-zA-Z0-9._@-]+$'; then
  echo "ERROR: invalid Homebrew package name" >&2
  exit 1
fi
in_nixpkgs=$(search_nixpkgs_batch "$all_names") || {
  echo "ERROR: pinned nixpkgs search failed" >&2
  exit 1
}
"$JQ" -e 'type == "object"' <<< "$in_nixpkgs" >/dev/null

echo "Checking if homebrew packages are available in nixpkgs..."
failed=0
violations=""

# Check if package is in exclusion list
is_excluded() {
  "$JQ" -e --arg kind "$1" --arg pkg "$2" ".exceptions[\$kind][\$pkg] != null" <<< "$policy" >/dev/null
}

# Get exclusion reason
get_exclusion_reason() {
  "$JQ" -r --arg kind "$1" --arg pkg "$2" ".exceptions[\$kind][\$pkg]" <<< "$policy"
}

is_available() {
  local pkg="$1" attrs attr metadata apply
  attrs=$("$JQ" -r --arg name "$pkg" "to_entries[] | select(.value.pname == \$name or (.key | split(\".\") | last) == \$name) | .key" <<< "$in_nixpkgs") || return 2
  while IFS= read -r attr; do
    [[ -z "$attr" ]] && continue
    apply=$("$JQ" -nr --arg attr "$attr" "\"f: f \" + ((\$attr | split(\".\") | .[2:]) | tojson)") || return 2
    metadata=$(nix eval --json .#lib.homebrewPackageAvailability --apply "$apply") || {
      echo "ERROR: could not evaluate metadata for $attr" >&2
      return 2
    }
    if ! "$JQ" -e 'type == "boolean"' <<< "$metadata" >/dev/null; then
      echo "ERROR: invalid metadata for $attr" >&2
      return 2
    fi
    if "$JQ" -e '.' <<< "$metadata" >/dev/null; then
      return 0
    fi
  done <<< "$attrs"
  return 1
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
  if is_excluded brews "$package"; then
    reason=$(get_exclusion_reason brews "$package")
    echo "⊘ SKIP: '$package' (brew) - $reason"
    continue
  fi

  # Membership test against the single batched search below. The previous form
  # ran `nix search` once per package (measured ~3.2s each, warmed) and decided
  # the result by grepping its human-readable output for the word
  # "legacyPackages" — coupled to a display format that carries no such promise.
  availability=0; is_available "$package" || availability=$?
  if [ "$availability" -eq 2 ]; then exit 1; fi
  if [ "$availability" -eq 0 ]; then
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
  if is_excluded casks "$package"; then
    reason=$(get_exclusion_reason casks "$package")
    echo "⊘ SKIP: '$package' (cask) - $reason"
    continue
  fi

  # Membership test against the single batched search below. The previous form
  # ran `nix search` once per package (measured ~3.2s each, warmed) and decided
  # the result by grepping its human-readable output for the word
  # "legacyPackages" — coupled to a display format that carries no such promise.
  availability=0; is_available "$package" || availability=$?
  if [ "$availability" -eq 2 ]; then exit 1; fi
  if [ "$availability" -eq 0 ]; then
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
