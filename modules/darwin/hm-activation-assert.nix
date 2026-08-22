# Assert that home-manager activation actually completed.
#
# Upstream's nix-darwin home-manager module emits its user activation as a bare
# `launchctl asuser ... activation-<user>` line into
# `system.activationScripts.postActivation.text` and never inspects the exit
# code. Activation in this repo additionally runs `set +e` (Rule 1, see
# docs/ACTIVATION-SCRIPTS-RULES.md), so a home-manager abort — a link-target
# collision, a failing activation step — is discarded twice over: the rebuild
# prints "✅ Activation complete", exits 0, and the operator has no signal that
# no user file and no user LaunchAgent plist was written.
#
# home-manager creates its `current-home` GC root as the very last thing it
# does, after every activation step. That link resolving to the generation in
# THIS closure is therefore proof the whole user activation ran; anything else
# means it stopped partway.
#
# `|| exit 1` is the whole point and is not redundant with `set -e` — see the
# same note on the cluster rebuild gate. Exiting here leaves
# /run/current-system pointing at the previous generation, which is correct: a
# generation whose user half never applied must not be advertised as live, or
# the generation-parity preflight reports a deployment that is not running.
#
# Ordered after every other postActivation contributor (mkAfter is 1500) so the
# system half is fully applied before the rebuild fails.

{ config, lib, ... }:

let
  userConfig = import ../../lib/user-config.nix;
  inherit (userConfig.user) name homeDir;
  hmGeneration = config.home-manager.users.${name}.home.activationPackage;
in
{
  system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
    hmGenLink="${homeDir}/.local/state/home-manager/gcroots/current-home"
    hmParentArgs="$(ps -p "$PPID" -ww -o args= || true)"

    if [[ -v DRY_RUN || "$hmParentArgs" == *" --dry-run"* ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] dry run — skipping home-manager generation check"
    elif [ "$(readlink "$hmGenLink" 2>/dev/null)" = "${hmGeneration}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ✓ home-manager generation verified: ${hmGeneration}"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] home-manager activation did NOT complete for ${name}" >&2
      echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]   expected: ${hmGeneration}" >&2
      echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]   live:     $(readlink "$hmGenLink" 2>/dev/null || echo '<no current-home link>')" >&2
      echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] User files and user LaunchAgent plists are stale or unwritten." >&2
      echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Scroll up to the home-manager output for the step that stopped." >&2
      echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] /run/current-system was NOT advanced — this deploy did not happen." >&2
      exit 1
    fi
  '';
}
