# comin GitOps service.
#
# comin reads `access_token_path` once, when it loads its configuration at start. The
# `comin-token-reload` daemon watches the token's directory and restarts comin when it changes, so a
# refreshed token reaches the next fetch. It never restarts comin during a deployment; see
# ./scripts/comin-token-reload.sh.
{
  config,
  lib,
  pkgs,
  launchdTrampolineArgs,
  ...
}:

let
  cfg = config.services.cominGitOps;
  cominLabel = "com.github.nlewo.comin";
  tokenReloadPkg = pkgs.writeShellApplication {
    name = "comin-token-reload";
    runtimeInputs = [
      config.services.comin.package
      pkgs.jq
    ];
    runtimeEnv.COMIN_LABEL = cominLabel;
    text = builtins.readFile ./scripts/comin-token-reload.sh;
  };
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

    launchd.daemons.comin-token-reload.serviceConfig = {
      Label = "com.nix-darwin.comin-token-reload";
      # The named trampoline waits for /nix/store before execing this argument vector.
      ProgramArguments = launchdTrampolineArgs "comin-token-reload" [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${lib.getExe tokenReloadPkg}"
      ];
      # The directory, not the file: a token written by rename replaces the file's inode.
      WatchPaths = [ (dirOf cfg.accessTokenPath) ];
      RunAtLoad = false;
      KeepAlive = false;
      StandardOutPath = "/var/log/comin-token-reload.log";
      StandardErrorPath = "/var/log/comin-token-reload.log";
    };
  };
}
