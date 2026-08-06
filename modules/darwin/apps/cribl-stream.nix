# Cribl Stream Service Management (Apple container)
#
# Runs a single-instance Cribl Stream node in an Apple `container` as the
# local single egress for this Mac: everything collected here ships to this
# Stream, which enriches, persistent-queues, and forwards once to the Proxmox
# Stream tier (instead of many local sources each dialing Proxmox).
#
# Script-free: native launchd user agents drive the lifecycle.
#   * apple-container-runtime (shared module) — one-shot `container system
#     start --enable-kernel-install` (installs the kata kernel
#     non-interactively on first run; no-op thereafter). The apiserver it
#     starts self-registers with launchd and persists independently.
#   * cribl-stream — `container run` in the FOREGROUND (no -d), so launchd's
#     KeepAlive directly supervises the container: when it exits, launchd
#     restarts it. `--rm` keeps the fixed name free across restarts.
# `container` is per-user (talks to the login user's container-apiserver), so
# these are user agents, not root daemons.
#
# Config is a GitOps file tree (configFiles) installed into the bind-mounted
# volume's local/cribl/, mirroring programs.cribl-edge standalone mode. Cribl
# reloads local config without a restart and writes its own logs to
# <dataDir>/volume/log/cribl.log.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.cribl-stream;

  inherit (config.programs.apple-container-runtime) containerBin;
  mount = "/opt/cribl/config-volume"; # CRIBL_VOLUME_DIR inside the container
  volumeDir = "${cfg.dataDir}/volume"; # host side of the bind mount

  runArgs = lib.concatStringsSep " " (
    [
      containerBin
      "run"
      "--rm"
      "--name"
      cfg.containerName
      "--cpus"
      (toString cfg.cpus)
      "--memory"
      cfg.memory
      "--publish"
      "127.0.0.1:${toString cfg.apiPort}:9000"
      "--publish"
      "127.0.0.1:${toString cfg.inputPort}:${toString cfg.inputPort}"
      "--env"
      "CRIBL_VOLUME_DIR=${mount}"
      "--env"
      "CRIBL_MAX_WORKERS=${toString cfg.maxWorkers}"
      "--volume"
      "${volumeDir}:${mount}"
    ]
    ++ lib.concatMap (s: [
      "--dns"
      s
    ]) cfg.dnsServers
    ++ lib.concatMap (d: [
      "--dns-search"
      d
    ]) cfg.dnsSearch
    ++ [ cfg.image ] # image must be the final positional arg
  );

  # Install the config-as-code tree into the writable volume (owned by the user,
  # 0644 so Cribl can rewrite). Same native idiom as cribl-edge.
  configInstall = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (rel: text: ''
      /usr/bin/install -d -o ${cfg.user} -g ${cfg.group} "$(/usr/bin/dirname "${volumeDir}/local/cribl/${rel}")"
      /usr/bin/install -m 0644 -o ${cfg.user} -g ${cfg.group} ${
        pkgs.writeText (builtins.replaceStrings [ "/" ] [ "-" ] rel) text
      } "${volumeDir}/local/cribl/${rel}"
    '') cfg.configFiles
  );
in
{
  options.programs.cribl-stream = {
    enable = lib.mkEnableOption "Local Cribl Stream node in an Apple container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "cribl/cribl:latest";
      description = "OCI image for the Cribl Stream node.";
    };

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "cribl-stream";
      description = "Fixed Apple container name.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/cribl-stream";
      description = ''
        Host directory for Stream state. <dataDir>/volume is bind-mounted into
        the container at /opt/cribl/config-volume (CRIBL_VOLUME_DIR); the
        config-as-code tree, logs, and persistent queues live under it.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        macOS login user that owns the data dir and runs the lifecycle agents.
        Apple `container` is per-user (talks to that user's container-apiserver).
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "staff";
      description = "Primary group of the login user (macOS default: staff).";
    };

    cpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "vCPU cap for the container; bounds host CPU usage.";
    };

    memory = lib.mkOption {
      type = lib.types.str;
      default = "1g";
      description = "Memory cap for the container.";
    };

    maxWorkers = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Cribl worker process count.";
    };

    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "DNS nameservers for the container, for resolving LAN service names.";
    };

    dnsSearch = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "DNS search domains for the container.";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Cribl UI/API port, published on 127.0.0.1.";
    };

    inputPort = lib.mkOption {
      type = lib.types.port;
      default = 10301;
      description = "cribl_tcp (S2S) input port for local Edge → Stream, published on 127.0.0.1.";
    };

    configFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = { };
      description = ''
        Declarative Cribl Stream config files, keyed by path relative to the
        volume's local/cribl/ (inputs.yml, outputs.yml,
        pipelines/<name>/conf.yml). Installed on every activation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Create the volume + log dirs and render the config-as-code tree.
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${cfg.user} -g ${cfg.group} ${volumeDir} ${cfg.dataDir}/logs
      ${configInstall}
    '';

    # Shared one-shot brings up the container runtime/apiserver (idempotent);
    # mkDefault so a host can still point the shared module elsewhere.
    programs.apple-container-runtime = {
      enable = lib.mkDefault true;
      user = lib.mkDefault cfg.user;
      group = lib.mkDefault cfg.group;
    };

    # Foreground `container run` supervised by launchd KeepAlive — no wrapper
    # script. A stale same-named container is force-removed first (so a
    # hard-killed leftover can't block restart), then `exec` hands the run
    # process to launchd. Cribl's own logs go to <volume>/log/cribl.log, so
    # launchd stdout is discarded; stderr keeps any launch errors.
    launchd.user.agents.cribl-stream.serviceConfig = {
      Label = "com.nix-darwin.cribl-stream";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "${containerBin} delete --force ${cfg.containerName} 2>/dev/null || true; exec ${runArgs}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      StandardOutPath = "/dev/null";
      StandardErrorPath = "${cfg.dataDir}/logs/cribl-stream.err.log";
    };
  };
}
