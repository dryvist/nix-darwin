#!/usr/bin/env bash
# Build home-manager configuration with error detection
# Usage: ./scripts/workflows/build-hm.sh [OUTPUT_LINK]
# Exit codes: 0=success, 1=build failed or error detected

set -euo pipefail

OUTPUT_LINK="${1:-result-hm}"
BUILD_OUTPUT=$(mktemp)
trap 'rm -f "$BUILD_OUTPUT"' EXIT

# Build and capture output (--print-build-logs shows derivation output inline).
# --impure required because services.aiStack.defaultLocalModelId is sourced
# at evaluation time from `builtins.getEnv "AI_MODEL_LOCAL_LLM"` (the value
# lives in Doppler / org variable / no-password automation keychain — never
# committed). The build will fail loudly with a clear error if the env var
# is unset, so this stays explicit rather than wrapping nix with a guard.
nix build .#lib.ci.hmActivationPackage --impure --print-build-logs -o "$OUTPUT_LINK" 2>&1 | tee "$BUILD_OUTPUT"
build_exit_code=${PIPESTATUS[0]}

if [ "$build_exit_code" -ne 0 ]; then
  echo "::error::nix build failed with exit code $build_exit_code"
  exit $build_exit_code
fi

# Fail on errors (warnings are logged but don't fail the build)
if grep -qE "^error:" "$BUILD_OUTPUT"; then
  matched_line=$(grep -E "^error:" "$BUILD_OUTPUT" | head -1)
  echo "::error::Build failed: $matched_line"
  exit 1
fi

# Log warnings for visibility
if grep -qE "^warning:" "$BUILD_OUTPUT"; then
  grep -E "^warning:" "$BUILD_OUTPUT" | while read -r line; do
    echo "::warning::$line"
  done
fi

echo "Build completed successfully: $OUTPUT_LINK"
