{
  lib,
  pkgs,
  hostConfig,
  ...
}:
let
  inherit (import ../../lib/user-config.nix) user;
  workstation = hostConfig.homebrew.enableWorkstationApps;
  stateDir = lib.escapeShellArg "${user.homeDir}/Library/Application Support/app-updates";
  runner = pkgs.writeShellApplication {
    name = "app-updates";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export mas=${if workstation then lib.getExe pkgs.mas else "/usr/bin/false"}
      export sudo=/usr/bin/sudo
      export notifier=/usr/bin/osascript
      export brew=/opt/homebrew/bin/brew
      export workstation=${if workstation then "1" else "0"}
      export PATH="$PATH:/usr/bin:/bin"
      ${builtins.readFile ./app-updates.sh}
    '';
  };
in
{
  system.defaults.CustomSystemPreferences = lib.mkIf workstation {
    "com.apple.commerce".AutoUpdate = true;
  };

  environment.etc."sudoers.d/app-updates" = lib.mkIf workstation {
    text = ''
      ${user.name} ALL=(root) TIMEOUT=3500 NOPASSWD: ${lib.getExe pkgs.mas} update --inaccurate --check-min-os
    '';
  };

  # Record initial activation once; rebuilding must not postpone stale-run alerts.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/sudo -u ${lib.escapeShellArg user.name} /bin/sh -c ${lib.escapeShellArg ''
      umask 077
      mkdir -p ${stateDir}
      if [ ! -e ${stateDir}/activated ]; then
        date +%s > ${stateDir}/activated
      fi
    ''}
  '';

  launchd.user.agents = {
    brew-upgrade.serviceConfig.ProgramArguments = lib.mkForce [
      (lib.getExe runner)
      "brew"
    ];
    app-store-upgrade = lib.mkIf workstation {
      serviceConfig = {
        Label = "com.nix-darwin.app-store-upgrade";
        ProgramArguments = [
          (lib.getExe runner)
          "mas"
        ];
        StartCalendarInterval = [
          {
            Hour = 4;
            Minute = 40;
          }
        ];
        RunAtLoad = true;
        ProcessType = "Background";
        LowPriorityIO = true;
        EnvironmentVariables.HOME = user.homeDir;
        StandardOutPath = "${user.homeDir}/Library/Logs/app-store-upgrade.log";
        StandardErrorPath = "${user.homeDir}/Library/Logs/app-store-upgrade.log";
      };
    };
    app-update-health = lib.mkIf workstation {
      serviceConfig = {
        Label = "com.nix-darwin.app-update-health";
        ProgramArguments = [
          (lib.getExe runner)
          "health"
        ];
        StartInterval = 3600;
        RunAtLoad = true;
        EnvironmentVariables.HOME = user.homeDir;
        StandardOutPath = "${user.homeDir}/Library/Logs/app-update-health.log";
        StandardErrorPath = "${user.homeDir}/Library/Logs/app-update-health.log";
      };
    };
  };
}
