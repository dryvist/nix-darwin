# Activation Error Tracking Module
# Provides comprehensive error tracking for darwin-rebuild activation phases
# Helps diagnose failures by tracking which phase failed and why
#
# Problem this solves:
# - The launchctl asuser call (home-manager activation) succeeds but may return
#   exit code 2, causing set -e to abort the entire script
# - Without tracking, we can't see which phase actually failed
# - This leaves users unable to diagnose the real issue
#
# Solution:
# - Track each activation phase with exit codes
# - Allow non-critical phases to fail without aborting (enforced by 'set +e' in preActivation)
# - Report comprehensive error information with timestamps
# - Keep debug output for future diagnostics
# - Follow CRITICAL RULES in docs/ACTIVATION-SCRIPTS-RULES.md:
#   * NEVER use 'set -e' in activation scripts
#   * TREAT ALL ERRORS AS WARNINGS, not fatal failures
#   * Symlink update is the CRITICAL phase - must never abort before it

{ lib, ... }:

{
  # Post-activation script that wraps home-manager activation
  # Captures exit codes and allows script to continue
  # Uses mkBefore to ensure functions are available to other activation scripts
  system.activationScripts.postActivation.text = lib.mkBefore ''
    # ====================================================================
    # Activation Error Tracking & Resilience
    # ====================================================================
    # The home-manager activation can succeed but return non-zero exit codes
    # This section tracks each phase and prevents premature script exit

    PHASE_START_TIME=$(date '+%s')
    ACTIVATION_PHASES_FAILED=""
    TOTAL_PHASES_FAILED=0

    # Function to track activation phase results
    track_activation_phase() {
      local phase_name="$1"
      local exit_code="$2"
      local elapsed_time=$(($(date '+%s') - PHASE_START_TIME))

      if [ "$exit_code" -ne 0 ]; then
        TOTAL_PHASES_FAILED=$((TOTAL_PHASES_FAILED + 1))
        ACTIVATION_PHASES_FAILED="''${ACTIVATION_PHASES_FAILED}
        - $phase_name (exit $exit_code, elapsed: $${elapsed_time}s)"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Activation phase '$phase_name' returned exit code $exit_code (elapsed: $${elapsed_time}s)" >&2
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] Activation phase '$phase_name' completed successfully (elapsed: $${elapsed_time}s)"
      fi
    }

    # Print final activation summary
    print_activation_summary() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ============================================"
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Activation Complete"
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ============================================"

      if [ "''${TOTAL_PHASES_FAILED}" -gt 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] ''${TOTAL_PHASES_FAILED} activation phase(s) had non-zero exit codes:" >&2
        echo "''${ACTIVATION_PHASES_FAILED}" >&2
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Note: Some phases may succeed despite returning non-zero exit codes"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Check /run/current-system symlink to verify if activation actually succeeded"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] All activation phases completed successfully"
      fi
    }

    # Export functions for subshells
    export -f track_activation_phase
    export -f print_activation_summary
    export ACTIVATION_PHASES_FAILED TOTAL_PHASES_FAILED PHASE_START_TIME
  '';
}
