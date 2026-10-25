{ config, lib, pkgs, ... }:

let
  cfg = config.services.macSchedule;

  scheduleJob = pkgs.writeShellApplication {
    name = "mac-schedule";
    runtimeEnv = {
      MAC_SCHEDULE_CURL_BIN = "${pkgs.curl}/bin/curl";
      MAC_SCHEDULE_GATE_BIN = lib.getExe config.system.clusterRebuildGate.gatePkg;
      MAC_SCHEDULE_JQ_BIN = "${pkgs.jq}/bin/jq";
      MAC_SCHEDULE_LOGGER_BIN = "/usr/bin/logger";
      MAC_SCHEDULE_MODEL_ENDPOINT = cfg.modelEndpoint;
      MAC_SCHEDULE_MODEL_ID = cfg.modelId;
      MAC_SCHEDULE_PMSET_BIN = "/usr/bin/pmset";
    };
    text = builtins.readFile ./scripts/mac-schedule.sh;
  };
in
{
  options.services.macSchedule = {
    enable = lib.mkEnableOption "the scheduled resident-model command";

    startCalendarInterval = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.int);
      default = [
        {
          Hour = 23;
          Minute = 0;
        }
      ];
      description = "Launchd calendar intervals for the scheduled command.";
    };

    modelEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Base URL of the resident OpenAI-compatible endpoint.";
    };

    modelId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Model ID that must be listed before the command runs.";
    };

    command = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Executable and arguments to run after all schedule guards pass.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.modelEndpoint != "";
        message = "services.macSchedule.modelEndpoint must be set when enabled.";
      }
      {
        assertion = cfg.modelId != "";
        message = "services.macSchedule.modelId must be set when enabled.";
      }
      {
        assertion = cfg.command != [ ];
        message = "services.macSchedule.command must be set when enabled.";
      }
      {
        assertion = cfg.startCalendarInterval != [ ];
        message = "services.macSchedule.startCalendarInterval must not be empty when enabled.";
      }
    ];

    launchd.user.agents.mac-schedule.serviceConfig = {
      Label = "com.nix-darwin.mac-schedule";
      ProgramArguments = [ (lib.getExe scheduleJob) ] ++ cfg.command;
      RunAtLoad = false;
      StartCalendarInterval = cfg.startCalendarInterval;
    };
  };
}
