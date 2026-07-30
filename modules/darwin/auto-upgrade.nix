{
  config,
  hostConfig,
  lib,
  ...
}:

let
  cfg = config.system.nixDarwinAutoUpgrade;
in
{
  options.system.nixDarwinAutoUpgrade = {
    enable = lib.mkEnableOption "weekly nix-darwin auto-upgrade via launchd";

    flake = lib.mkOption {
      type = lib.types.str;
      # Pinned to main: nix-darwin is git-flow (default branch develop), so
      # an unref'd url would resolve to develop and auto-apply unreleased
      # commits weekly, unattended.
      default = "github:dryvist/nix-darwin/main";
      description = "Remote nix-darwin flake to apply.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/nix-darwin-auto-upgrade";
      description = "Directory for auto-upgrade stdout and stderr logs.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.nix-darwin-auto-upgrade.serviceConfig = {
      Label = "org.nixos.darwin-auto-upgrade";
      ProgramArguments = [
        "/run/current-system/sw/bin/darwin-rebuild"
        "switch"
        "--flake"
        "${cfg.flake}#${hostConfig.hostName}"
        "--refresh"
        "--no-write-lock-file"
        "--print-build-logs"
      ];
      StartCalendarInterval = [
        {
          Weekday = 5;
          Hour = 0;
          Minute = 0;
        }
      ];
      RunAtLoad = false;
      ProcessType = "Background";
      UserName = "root";
      GroupName = "wheel";
      StandardOutPath = "${cfg.logDir}/auto-upgrade.log";
      StandardErrorPath = "${cfg.logDir}/auto-upgrade.error.log";
      EnvironmentVariables = {
        HOME = "/var/root";
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin";
      };
    };

    system.activationScripts.nixDarwinAutoUpgradeDirs.text = ''
      /usr/bin/install -d -o root -g wheel -m 0755 "${cfg.logDir}"
    '';

    environment.etc."newsyslog.d/nix-darwin-auto-upgrade.conf".text = ''
      # logfilename [owner:group] mode count size when flags
      ${cfg.logDir}/auto-upgrade.log root:wheel 644 6 2048 * J
      ${cfg.logDir}/auto-upgrade.error.log root:wheel 644 6 2048 * J
    '';
  };
}
