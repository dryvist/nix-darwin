{ config, lib, ... }:

let
  cfg = config.services.cominGitOps;
in
{
  options.services.cominGitOps = {
    enable = lib.mkEnableOption "the comin GitOps service";

    remoteUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Repository URL consumed by comin.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch that comin deploys with the switch operation.";
    };

    accessTokenPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to the file containing the remote access token.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.remoteUrl != "";
        message = "services.cominGitOps.remoteUrl must be set when enabled.";
      }
      {
        assertion = cfg.branch != "";
        message = "services.cominGitOps.branch must be set when enabled.";
      }
      {
        assertion = cfg.accessTokenPath != "";
        message = "services.cominGitOps.accessTokenPath must be set when enabled.";
      }
    ];

    services.comin = {
      enable = true;
      remotes = [
        {
          name = "main";
          url = cfg.remoteUrl;
          auth.access_token_path = cfg.accessTokenPath;
          branches.main = {
            name = cfg.branch;
            operation = "switch";
          };
        }
      ];
      deployConfirmer.mode = "manual";
    };
  };
}
