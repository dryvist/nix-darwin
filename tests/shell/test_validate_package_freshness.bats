#!/usr/bin/env bats
# Test validate-package-freshness.sh logic
#
# Tests the key behaviors introduced/changed in the determinateNix migration:
#   - jq guard fires before first jq usage
#   - Dynamic ROOT_NIXPKGS_NODE resolution (root.inputs.nixpkgs may be nixpkgs_3)
#   - nixpkgs_2 and nix are exempt (DeterminateSystems transitive deps)
#   - Glob pattern matching for exemptions (flake-compat*)

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../../scripts/validate-package-freshness.sh"

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR" || exit 1
  NOW=$(date +%s)
  FRESH=$((NOW - 86400))            # 1 day ago
  STALE_CRITICAL=$((NOW - 2678400)) # 31 days ago (>30 threshold)
  STALE_GENERAL=$((NOW - 7862400))  # 91 days ago (>90 threshold)
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# Helper: write a flake.lock where root.inputs.nixpkgs points to <alias>,
# and that alias node has the given lastModified timestamp.
# Optional fourth argument is raw JSON to append as additional nodes.
make_flake_lock() {
  local alias="$1"
  local lastmod="$2"
  local extra="${3:-}"
  cat > flake.lock <<EOF
{
  "nodes": {
    "root": {
      "inputs": {
        "nixpkgs": "$alias"
      }
    },
    "$alias": {
      "locked": { "lastModified": $lastmod }
    }$extra
  },
  "version": 7
}
EOF
}

# ── Missing flake.lock ────────────────────────────────────────────────────────

@test "validate-package-freshness.sh: missing flake.lock exits 0 with warning" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No flake.lock found" ]]
}

# ── Fresh packages pass ───────────────────────────────────────────────────────

@test "validate-package-freshness.sh: fresh nixpkgs passes critical check" {
  make_flake_lock "nixpkgs" "$FRESH"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OK" ]]
}

# ── Stale packages are reported, never failed ─────────────────────────────────

@test "validate-package-freshness.sh: stale critical package is reported and exits 0" {
  make_flake_lock "nixpkgs" "$STALE_CRITICAL"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "STALE" ]]
  [[ "$output" =~ "report only" ]]
}

@test "validate-package-freshness.sh: stale general package (home-manager) is reported and exits 0" {
  make_flake_lock "nixpkgs" "$FRESH" ',
    "home-manager": {
      "locked": { "lastModified": '"$STALE_GENERAL"' }
    }'
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "STALE" ]]
}

# ── Dynamic ROOT_NIXPKGS_NODE resolution ─────────────────────────────────────

@test "validate-package-freshness.sh: stale nixpkgs_3 is reported when root points to it" {
  # When determinate brings its own nixpkgs, Nix renames ours to nixpkgs_3.
  # The script reads root.inputs.nixpkgs and must treat that node as critical.
  make_flake_lock "nixpkgs_3" "$STALE_CRITICAL"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "nixpkgs_3" ]]
  [[ "$output" =~ "STALE" ]]
}

@test "validate-package-freshness.sh: fresh nixpkgs_3 passes when root points to it" {
  make_flake_lock "nixpkgs_3" "$FRESH"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
}

# ── Exempt packages (DeterminateSystems transitive deps) ─────────────────────

@test "validate-package-freshness.sh: nixpkgs_2 is exempt even when stale" {
  # nixpkgs_2 is determinate's internal nixpkgs — must never trigger failure
  make_flake_lock "nixpkgs_3" "$FRESH" ',
    "nixpkgs_2": {
      "locked": { "lastModified": '"$STALE_GENERAL"' }
    }'
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "EXEMPT" ]]
  [[ "$output" =~ "nixpkgs_2" ]]
}

@test "validate-package-freshness.sh: nix (DeterminateSystems/nix-src) is exempt even when stale" {
  make_flake_lock "nixpkgs_3" "$FRESH" ',
    "nix": {
      "locked": { "lastModified": '"$STALE_GENERAL"' }
    }'
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "EXEMPT" ]]
}

# ── Glob pattern exemptions ───────────────────────────────────────────────────

@test "validate-package-freshness.sh: flake-compat_2 is exempt via flake-compat* glob" {
  make_flake_lock "nixpkgs" "$FRESH" ',
    "flake-compat_2": {
      "locked": { "lastModified": '"$STALE_GENERAL"' }
    }'
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "EXEMPT" ]]
  [[ "$output" =~ "flake-compat_2" ]]
}
