# Self-heal critical KeepAlive LaunchDaemons after every activation.
#
# nix-darwin only (re)starts a daemon when its plist CONTENT changes. A
# KeepAlive daemon that has crash-looped into launchd's "penalty box"
# (`launchctl print` shows `state = spawn scheduled`, no `pid`) keeps its
# unchanged plist, so a plain `darwin-rebuild switch` leaves it dead and
# telemetry silently goes dark for days.
#
# launchd-bootstrap.nix does not catch this: it only bootstraps daemons whose
# `launchctl print` FAILS (never-loaded), and a penalty-boxed daemon is still
# loaded. It also globs only `org.nixos.*` / `com.nix-darwin.*` plists, so a
# daemon labelled `com.<user>.*` is invisible to it entirely.
#
# This module force-reloads (bootout + bootstrap) each listed daemon that is
# not currently running. It NEVER uses `launchctl kickstart`, which HANGS
# indefinitely on a penalty-boxed daemon (it blocks on a spawn launchd will
# not perform).
#
# Runbook + rationale: docs/LAUNCHD-SELF-HEAL.md
# Activation-script constraints obeyed here: docs/ACTIVATION-SCRIPTS-RULES.md

{ config, lib, ... }:

let
  cfg = config.services.launchdSelfHeal;
in
{
  options.services.launchdSelfHeal.labels = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "com.nix-darwin.cribl-edge" ];
    description = ''
      LaunchDaemon labels that must always be running. After each activation,
      any listed daemon that is loaded-but-not-running (penalty box) or absent
      is force-reloaded via `launchctl bootout` + `bootstrap`. Only meaningful
      for KeepAlive daemons. The plist is expected at
      `/Library/LaunchDaemons/<label>.plist`. Each daemon module registers its
      own label here, next to the daemon definition, so a rename can't silently
      drop coverage.
    '';
  };

  config =
    let
      uniqueLabels = lib.unique cfg.labels;
    in
    lib.mkIf (uniqueLabels != [ ]) {
      # postActivation + mkAfter: run after nix-darwin's own launchd reconcile so
      # we observe the post-switch state. Follows docs/ACTIVATION-SCRIPTS-RULES.md
      # — no `set -e`/early exit; every failure is a non-fatal warning so the
      # critical /run/current-system symlink update is never blocked.
      system.activationScripts.postActivation.text = lib.mkAfter ''
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] launchd self-heal: checking ${toString (builtins.length uniqueLabels)} critical daemon(s)..."
        for label in ${lib.escapeShellArgs uniqueLabels}; do
          plist="/Library/LaunchDaemons/$label.plist"
          if [ ! -f "$plist" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] launchd self-heal: $label plist missing, skipping" >&2
            continue
          fi
          # A running daemon prints a numeric `pid = N`; a dead/penalty-boxed one
          # (state = spawn scheduled) has no pid line even though it is loaded.
          if /bin/launchctl print system/"$label" 2>/dev/null | grep -qE '^[[:space:]]*pid = [0-9]+[[:space:]]*$'; then
            continue
          fi
          # Not running. Force a clean reload. NEVER `launchctl kickstart` here —
          # it HANGS forever on a penalty-boxed daemon. bootout clears the wedged
          # state; bootstrap starts it fresh (RunAtLoad). bootout is allowed to
          # fail (daemon may be fully absent), hence `|| true`.
          echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] launchd self-heal: $label not running; reloading (bootout+bootstrap)" >&2
          /bin/launchctl bootout system/"$label" 2>/dev/null || true
          if /bin/launchctl bootstrap system "$plist" 2>/dev/null; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] launchd self-heal: $label reloaded" >&2
          else
            echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] launchd self-heal: $label bootstrap failed" >&2
          fi
        done
      '';
    };
}
