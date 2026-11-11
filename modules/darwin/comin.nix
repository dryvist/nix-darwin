# comin GitOps service.
#
# comin reads `access_token_path` once, when it loads its configuration at start. The
# `comin-token-reload` daemon watches the token's directory and restarts comin when it changes, so a
# refreshed token reaches the next fetch. It restarts comin at most once per token rewrite, and not
# while comin is fetching, evaluating, building or deploying; see ./scripts/comin-token-reload.sh.
#
# The deploy confirmer stays `manual`. The `comin-confirmer` daemon confirms a waiting generation
# only when the cluster rebuild gate allows activation; while the host is clustered it confirms
# nothing, logs the gate's refusal, and checks again on the next interval. A hold file
# (services.cominGitOps.holdFile, set with `comin-hold`) stops confirmation for at most 12 hours. See
# ./scripts/comin-confirmer.sh.
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
    runtimeEnv = {
      COMIN_LABEL = cominLabel;
      COMIN_TOKEN_PATH = cfg.accessTokenPath;
    };
    text = builtins.readFile ./scripts/comin-token-reload.sh;
  };
  # coreutils first in PATH: the scripts parse hold times with GNU `date -d`.
  confirmerPkg = pkgs.writeShellApplication {
    name = "comin-confirmer";
    runtimeInputs = [
      pkgs.coreutils
      config.services.comin.package
      pkgs.jq
    ];
    runtimeEnv = {
      CLUSTER_REBUILD_GATE_BIN = lib.getExe config.system.clusterRebuildGate.gatePkg;
      COMIN_HOLD_FILE = cfg.holdFile;
    };
    text = builtins.readFile ./scripts/comin-confirmer.sh;
  };
  holdPkg = pkgs.writeShellApplication {
    name = "comin-hold";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv.COMIN_HOLD_FILE = cfg.holdFile;
    text = builtins.readFile ./scripts/comin-hold.sh;
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

    confirmInterval = lib.mkOption {
      type = lib.types.int;
      default = 293;
      description = "Seconds between confirmer runs; bounds how long an allowed generation waits for confirmation.";
    };

    holdFile = lib.mkOption {
      type = lib.types.str;
      # /var/db: root-owned state that survives a reboot (/var/run is cleared at boot; /etc is
      # declared configuration).
      default = "/var/db/comin-hold";
      description = ''
        Hold file read by the confirmer. While it holds a valid hold the confirmer confirms nothing;
        set and clear it with `comin-hold` (root). See ./scripts/comin-confirmer.sh for the format.
      '';
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

    environment.systemPackages = [ holdPkg ];

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
      # The upstream default group, `users`, does not exist on macOS, so comin's control
      # server would fail to start. Root clients only: the confirmer and token reload run as root.
      grpc.unix_socket_group = "wheel";
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
      # Also once when loaded (boot, or a changed plist), so a comin still holding an older
      # token is restarted without waiting for the next rewrite.
      RunAtLoad = true;
      KeepAlive = false;
      StandardOutPath = "/var/log/comin-token-reload.log";
      StandardErrorPath = "/var/log/comin-token-reload.log";
    };

    launchd.daemons.comin-confirmer.serviceConfig = {
      Label = "com.nix-darwin.comin-confirmer";
      # The named trampoline waits for /nix/store before execing this argument vector.
      ProgramArguments = launchdTrampolineArgs "comin-confirmer" [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${lib.getExe confirmerPkg}"
      ];
      StartInterval = cfg.confirmInterval;
      RunAtLoad = false;
      KeepAlive = false;
      StandardOutPath = "/var/log/comin-confirmer.log";
      StandardErrorPath = "/var/log/comin-confirmer.log";
    };
  };
}
