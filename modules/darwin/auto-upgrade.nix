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
      default = "github:dryvist/nix-darwin";
      description = "Remote nix-darwin flake to apply.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/nix-darwin-auto-upgrade";
      description = "Directory for auto-upgrade stdout and stderr logs.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/db/nix-darwin-auto-upgrade";
      description = "Directory for persisted auto-upgrade state.";
    };

    targetUtc = {
      weekday = lib.mkOption {
        type = lib.types.ints.between 1 7;
        default = 5;
        description = "UTC weekday to run, using ISO numbering where Monday is 1 and Friday is 5.";
      };

      hour = lib.mkOption {
        type = lib.types.ints.between 0 23;
        default = 0;
        description = "UTC hour to run.";
      };

      minute = lib.mkOption {
        type = lib.types.ints.between 0 59;
        default = 0;
        description = "UTC minute to run.";
      };
    };

    darwinRebuild = lib.mkOption {
      type = lib.types.str;
      default = "/run/current-system/sw/bin/darwin-rebuild";
      description = "darwin-rebuild binary used by the scheduled root daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.nix-darwin-auto-upgrade.serviceConfig = {
      Label = "org.nixos.darwin-auto-upgrade";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec /bin/bash \"$@\""
        "nix-darwin-auto-upgrade"
        "${./scripts/nix-darwin-auto-upgrade.sh}"
        cfg.flake
        hostConfig.hostName
        (toString cfg.targetUtc.weekday)
        (toString cfg.targetUtc.hour)
        (toString cfg.targetUtc.minute)
        cfg.stateDir
        "nix-darwin-auto-upgrade"
        cfg.darwinRebuild
      ];
      StartCalendarInterval = [
        {
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
      /usr/bin/install -d -o root -g wheel -m 0755 "${cfg.logDir}" "${cfg.stateDir}"
    '';

    environment.etc."newsyslog.d/nix-darwin-auto-upgrade.conf".text = ''
      # logfilename [owner:group] mode count size when flags
      ${cfg.logDir}/auto-upgrade.log root:wheel 644 6 2048 * J
      ${cfg.logDir}/auto-upgrade.error.log root:wheel 644 6 2048 * J
    '';
  };
}
