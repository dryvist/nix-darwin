# Cluster maintenance window — opened and closed by the cluster, not by a human.
#
# A timed LaunchAgent reconciles a shared maintenance-window task against live
# cluster state: opened when this host has a rank running, its expiry pushed
# out every tick while that holds, marked done once the rank is gone. The
# estate's "hands off this host" flag therefore tracks reality with no operator
# step anywhere in a cluster cycle.
#
# WHY A TIMER AND NOT A LINK-UP/LINK-DOWN HOOK. The window must never be able
# to delay a rank start or a teardown — protection domains are physics, the
# window is coordination — and a reconciler off the cluster's critical path
# cannot delay it even if the API is down, hung, or unreachable. It is also
# self-healing where an edge hook is not: a window orphaned by a crash, or a
# close that failed on a flaky network, converges on the next tick instead of
# being lost with the edge that missed it. The cost is bounded latency
# (`interval`), which is the right thing to trade for coordination.
#
# LABEL. `dev.mlx-cluster.maintenance-window` is in the cluster-quiesce KEEP
# allowlist prefix (`dev.mlx-cluster.`), which is load-bearing rather than
# cosmetic: quiesce boots out every user agent outside that allowlist at
# link-up, so an agent named anything else would be killed by the very event
# that opens the window and would never live to refresh or close it.
#
# CREDENTIALS. The agent runs under `openbao-run`, exactly as the llm-gate
# agent does: secret-zero (the secret backend address and this domain's
# AppRole) lives in a user-owned 0600 env file, the service-account password is
# fetched at start and injected as an environment variable, and nothing fetched
# is ever written to disk. The window API base URL is read from that same env
# file rather than from this repository, keeping internal hostnames out of
# public text — the secret backend address is already carried the same way.
#
# A MISSING OR UNSEEDED ENV FILE IS NOT AN OUTAGE. The reconciler logs loudly
# and exits 0; the cluster neither knows nor cares.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.clusterMaintenanceWindow;
  userConfig = import ../../lib/user-config.nix;

  windowPkg = pkgs.writeShellApplication {
    name = "cluster-maintenance-window";
    runtimeInputs = [ pkgs.jq ];
    runtimeEnv = {
      MLX_CLUSTER_RANK_LIVE_BIN = lib.getExe config.system.clusterRebuildGate.rankLivePackage;
      MLX_CLUSTER_WINDOW_PROJECT = toString cfg.projectId;
      MLX_CLUSTER_WINDOW_LABEL = cfg.label;
      MLX_CLUSTER_WINDOW_TITLE = cfg.windowTitle;
      MLX_CLUSTER_WINDOW_HOURS = toString cfg.windowHours;
      MLX_CLUSTER_WINDOW_STATE_FILE = cfg.stateFile;
    };
    text = builtins.readFile ./scripts/cluster-maintenance-window.sh;
  };
in
{
  options.services.clusterMaintenanceWindow = {
    enable = lib.mkEnableOption "automatic maintenance window while this host is running a cluster rank";

    projectId = lib.mkOption {
      type = lib.types.int;
      description = "Project the window task is created in. One task per window; this project is the estate-wide list every other actor checks before touching a host.";
    };

    label = lib.mkOption {
      type = lib.types.str;
      default = "maintenance";
      description = "Label title applied to the window task, resolved by title at runtime so no numeric id is baked in here.";
    };

    windowTitle = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}.${userConfig.baseDomain}";
      defaultText = lib.literalExpression "\"\${config.networking.hostName}.\${userConfig.baseDomain}\"";
      description = "Window task title — this host's FQDN, which is the convention every existing window in the project follows. Never an IP.";
    };

    windowHours = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = ''
        Rolling window length in hours, refreshed on every tick while a rank is
        live. Sized far longer than the reconcile interval so a few missed
        ticks cannot expire a window over a genuinely busy host, and far
        shorter than a stalled session so a window whose reconciler died ages
        out on its own instead of flagging a free host forever.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Seconds between reconcile passes. Bounds how long a window can lag reality in either direction (open after rank start, closed after teardown).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = userConfig.user.name;
      description = "Login user that owns the agent, its state file, and the secret-zero env file.";
    };

    secretZeroEnvFile = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/.local/share/mlx-cluster/bootstrap.env";
      description = ''
        User-owned 0600 or 0400 env file holding this agent's secret-zero: the
        secret backend address, the `apps` AppRole id/secret pair, and
        VIKUNJA_API_URL. Sourced unattended at each start by openbao-run, which
        refuses the file unless its mode is 0600 or 0400. Seeded out-of-band;
        rotation is a rewrite plus an agent restart. Absent or unseeded, the
        reconciler logs and exits 0 — it never blocks the cluster.
      '';
    };

    stateFile = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/Library/Application Support/mlx-cluster/maintenance-window-task";
      description = ''
        Holds the open window's task id, and nothing else. NOT a cluster-state
        marker: whether this host is clustered is asked of launchd every tick.
        This file only answers "which task did I open", so a stale one causes a
        refresh to fail and be forgotten, never a wrong hands-off verdict.
      '';
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/Library/Logs/mlx-cluster";
      description = "Directory for the agent's stdout/stderr. Every tick writes its decision here.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.openbao-run.enable = true;

    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0755 "${cfg.logDir}"
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0700 "$(dirname "${cfg.stateFile}")" "$(dirname "${cfg.secretZeroEnvFile}")"
    '';

    launchd.user.agents.cluster-maintenance-window.serviceConfig = {
      Label = "dev.mlx-cluster.maintenance-window";
      # /bin/bash rather than the Nix shebang — see docs/MACOS-LOCAL-NETWORK-TCC.md.
      ProgramArguments = [
        "/bin/bash"
        (lib.getExe config.programs.openbao-run.package)
        "--domain"
        "apps"
        "--env-file"
        cfg.secretZeroEnvFile
        "--secret"
        "VIKUNJA_PASSWORD=apps/vikunja#svc_mcp_rw_password"
        "--"
        (lib.getExe windowPkg)
      ];
      # A timer, not KeepAlive: each pass is a short one-shot that converges the
      # window and exits. RunAtLoad so a boot or a rebuild reconciles
      # immediately rather than waiting out a full interval.
      RunAtLoad = true;
      StartInterval = cfg.interval;
      EnvironmentVariables.HOME = userConfig.user.homeDir;
      StandardOutPath = "${cfg.logDir}/maintenance-window.log";
      StandardErrorPath = "${cfg.logDir}/maintenance-window.error.log";
    };

    environment.systemPackages = [ windowPkg ];
  };
}
