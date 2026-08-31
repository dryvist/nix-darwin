#!/usr/bin/env bash
# Build home-manager configuration with error detection
# Usage: ./scripts/workflows/build-hm.sh [OUTPUT_LINK]
# Exit codes: 0=success, 1=build failed or error detected

set -euo pipefail

OUTPUT_LINK="${1:-result-hm}"
BUILD_OUTPUT=$(mktemp)
trap 'rm -f "$BUILD_OUTPUT"' EXIT

# Build and capture output (--print-build-logs shows derivation output inline).
# Pure evaluation: services.aiStack.defaultLocalModelId is now sourced from the
# committed lib/user-config.nix, so no `--impure` (and no env/keychain) is needed.
nix build .#lib.ci.hmActivationPackage --print-build-logs -o "$OUTPUT_LINK" 2>&1 | tee "$BUILD_OUTPUT"
build_exit_code=${PIPESTATUS[0]}

if [ "$build_exit_code" -ne 0 ]; then
  echo "::error::nix build failed with exit code $build_exit_code"
  exit "$build_exit_code"
fi

# Fail on errors (warnings are logged but don't fail the build)
if grep -qE "^error:" "$BUILD_OUTPUT"; then
  matched_line=$(grep -m 1 -E "^error:" "$BUILD_OUTPUT")
  echo "::error::Build failed: $matched_line"
  exit 1
fi

# Log warnings for visibility
if grep -qE "^warning:" "$BUILD_OUTPUT"; then
  grep -E "^warning:" "$BUILD_OUTPUT" | while read -r line; do
    echo "::warning::$line"
  done
fi

# Source-build vs substitution breakdown.
#
# When this job runs long, the actionable question is always "what did we build
# from source instead of fetching?" — without this the log shows only that it
# was slow. Counts derivations nix chose to realise locally against paths it
# fetched, and names the worst offenders so the fix targets a real derivation.
built=$(grep -cE "^building '" "$BUILD_OUTPUT" || true)
fetched=$(grep -cE "^copying path|^downloading" "$BUILD_OUTPUT" || true)
echo "::notice::Realised locally: ${built} derivation(s); substituted: ${fetched} path(s)"
if [ "${built:-0}" -gt 0 ]; then
  echo "Top source-built derivations:"
  # Truncate inside awk, never with `head`. `sort` buffers its whole input, so a
  # `head` that closes the pipe after N lines SIGPIPEs it; under `set -o
  # pipefail` that propagates and `set -e` aborts the script — here that would
  # kill the build after a successful nix build but before it reports success.
  grep -E "^building '" "$BUILD_OUTPUT" |
    sed -E "s/^building '(.*)\.drv'.*/\1/; s@.*/[a-z0-9]{32}-@@" |
    sort | uniq -c | sort -rn | awk 'NR <= 15'
fi

echo "Build completed successfully: $OUTPUT_LINK"
