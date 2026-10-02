{
  lib,
  pkgs,
  hostConfig,
  ...
}:
let
  inherit (import ../../lib/user-config.nix) user;
  workstation = hostConfig.homebrew.enableWorkstationApps;
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

  launchd.user.agents = {
    app-store-upgrade = lib.mkIf workstation {
      serviceConfig = {
        Label = "com.nix-darwin.app-store-upgrade";
        ProgramArguments = [
          "/usr/bin/sudo"
          "-n"
          (lib.getExe pkgs.mas)
          "update"
          "--inaccurate"
          "--check-min-os"
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
  };
}
