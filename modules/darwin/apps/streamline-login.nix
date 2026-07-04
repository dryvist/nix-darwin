# Streamline Login Items
#
# Persistently disables unwanted LaunchAgents/LaunchDaemons and removes junk
# plists on every darwin-rebuild. Survives app reinstalls and updates.
#
# All configuration is in the host config (hosts/<host>/default.nix) — the
# one-stop shop for managing which services to disable or remove.
#
# Mechanisms:
#   - removePlists: deletes named plists from ~/Library/LaunchAgents/
#     (bootout + rm). Use for dead/junk plists that apps may recreate.
#   - disableUserServices: `launchctl disable gui/<uid>/<label>` — idempotent,
#     persists across reboots. Service plist stays but won't load.
#   - disableSystemServices: same for system domain (runs as root).
#   - pruneCompletionDirs: removes dangling zsh completion symlinks (e.g.
#     nix-homebrew's dead `_brew`) that make compinit warn on every login.

{ lib, config, ... }:

let
  cfg = config.programs.streamline-login;
  userConfig = import ../../../lib/user-config.nix;
  inherit (userConfig.user) homeDir name;
  ts = "$(date '+%Y-%m-%d %H:%M:%S')";
in
{
  options.programs.streamline-login = {
    enable = lib.mkEnableOption "login item streamlining (disable updaters, remove junk plists)";

    removePlists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Plist filenames (not full paths) under ~/Library/LaunchAgents/ to delete
        on every darwin-rebuild. The service is booted out before removal.
      '';
      example = [
        "com.google.keystone.agent.plist"
        "com.example.unwanted-updater.plist"
      ];
    };

    disableUserServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Service labels to persistently disable in the user launchd domain
        (gui/<uid>). Idempotent — safe to re-run on every rebuild.
      '';
      example = [
        "com.google.GoogleUpdater.wake"
        "us.zoom.updater"
      ];
    };

    disableSystemServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Service labels to persistently disable in the system launchd domain.
        Runs as root during activation (standard for nix-darwin).
      '';
      example = [
        "com.google.GoogleUpdater.wake.system"
        "com.duosecurity.duoappupdater"
      ];
    };

    pruneCompletionDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Absolute directories on `fpath` to prune of dangling (broken) zsh
        completion symlinks on every darwin-rebuild. Fixes the recurring
        `compinit: no such file or directory` login warning caused by
        nix-homebrew leaving a dead `_brew` symlink (its target under
        /opt/homebrew/completions is never materialized). Only symlinks whose
        target is missing are removed — real completions are untouched.
      '';
      example = [ "/opt/homebrew/share/zsh/site-functions" ];
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "${ts} [INFO] Streamline login items starting..."
      _cleanup_count=0
      _uid=$(/usr/bin/id -u ${name})

      # --- Remove unwanted user LaunchAgent plists ---
      ${lib.concatMapStringsSep "\n" (plist: ''
        if [ -f "${homeDir}/Library/LaunchAgents/${plist}" ]; then
          /bin/launchctl bootout "gui/$_uid/${lib.removeSuffix ".plist" plist}" 2>/dev/null || true
          rm -f "${homeDir}/Library/LaunchAgents/${plist}"
          echo "${ts} [INFO] Removed ${plist}"
          _cleanup_count=$((_cleanup_count + 1))
        fi
      '') cfg.removePlists}

      # --- Disable user-domain services ---
      ${lib.concatMapStringsSep "\n" (svc: ''
        if ! _err=$(/bin/launchctl disable "gui/$_uid/${svc}" 2>&1); then
          echo "${ts} [WARN] Failed to disable ${svc}: $_err" >&2
        fi
      '') cfg.disableUserServices}

      # --- Disable system-domain services ---
      ${lib.concatMapStringsSep "\n" (svc: ''
        if ! _err=$(/bin/launchctl disable "system/${svc}" 2>&1); then
          echo "${ts} [WARN] Failed to disable system/${svc}: $_err" >&2
        fi
      '') cfg.disableSystemServices}

      # --- Prune dangling zsh completion symlinks ---
      # nix-homebrew leaves a dead `_brew` symlink (its /opt/homebrew/completions
      # target is never materialized); compinit then warns on every login. Remove
      # only symlinks whose target is missing — real completions stay. POSIX glob:
      # an empty/no-match dir yields a literal that `[ -L ]` skips.
      ${lib.concatMapStringsSep "\n" (dir: ''
        if [ -d "${dir}" ]; then
          for _link in "${dir}"/*; do
            if [ -L "$_link" ] && [ ! -e "$_link" ]; then
              rm -f "$_link"
              echo "${ts} [INFO] Pruned dangling completion symlink $_link"
              _cleanup_count=$((_cleanup_count + 1))
            fi
          done
        fi
      '') cfg.pruneCompletionDirs}

      echo "${ts} [INFO] Streamline login complete ($_cleanup_count files removed, ${toString (builtins.length cfg.disableUserServices)} user + ${toString (builtins.length cfg.disableSystemServices)} system services disabled)"
    '';
  };
}
