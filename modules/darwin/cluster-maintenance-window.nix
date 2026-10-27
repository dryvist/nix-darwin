# Cluster maintenance window — opened and closed by the cluster, not by a human.
#
# A timed LaunchAgent reconciles a shared maintenance-window task against live
# cluster state: opened while this host is clustered, its expiry pushed out every
# tick while that holds, marked done once it no longer does. The estate's "hands
# off this host" flag therefore tracks reality with no operator step anywhere in
# a cluster cycle.
#
# CLUSTERED is the rebuild gate's definition (see ./scripts/cluster-rebuild-gate.sh):
# a rank is live, or the cluster link is up and its peer reports armed. Any state
# the gate would refuse on counts as clustered here too, so unreadable state keeps
# the window open.
#
# WHY A TIMER AND NOT A LINK-UP/LINK-DOWN HOOK. The window must never be able to
# delay a rank start or a teardown — protection domains are physics, the window is
# coordination — and a reconciler off the cluster's critical path cannot delay it
# even if the API is down, hung, or unreachable. It is also self-healing where an
# edge hook is not: a window orphaned by a crash, or a close that failed on a flaky
# network, converges on the next tick instead of being lost with the edge that
# missed it. The cost is bounded latency (`interval`), which is the right thing to
# trade for coordination.
#
# CREDENTIALS. The reconciler takes the API base URL and a bearer token from its
# environment, never from this repository, so no internal hostname or secret is
# baked in. By default it runs with whatever environment launchd gives it. A host
# layer that needs a secret-injecting command sets `launcherPrefix` to that
# command; it runs in front of the reconciler and must export both values.
#
# A MISSING TOKEN OR URL IS NOT AN OUTAGE. The reconciler logs loudly and exits 0;
# the cluster neither knows nor cares.
{
  lib,
  config,
  pkgs,
  launchdTrampolineArgs,
  ...
}:

let
  cfg = config.services.clusterMaintenanceWindow;
  userConfig = import ../../lib/user-config.nix;

  windowPkg = pkgs.writeShellApplication {
    name = "cluster-maintenance-window";
    runtimeInputs = [ pkgs.jq ];
    runtimeEnv = {
      # The rebuild gate reads its link and peer state under the same home.
      CLUSTER_USER_HOME = userConfig.user.homeDir;
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
    enable = lib.mkEnableOption "automatic maintenance window while this host is clustered";

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
        Rolling window length in hours, refreshed on every tick while the host is
        clustered. Sized far longer than the reconcile interval so a few missed
        ticks cannot expire a window over a genuinely busy host, and far shorter
        than a stalled session so a window whose reconciler died ages out on its
        own instead of flagging a free host forever.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Seconds between reconcile passes. Bounds how long a window can lag reality in either direction (open after clustering starts, closed after teardown).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = userConfig.user.name;
      description = "Login user that owns the agent and its state and log directories.";
    };

    launcherPrefix = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "/path/to/secret-launcher"
        "--"
      ];
      description = ''
        Argv placed in front of the reconciler, after the launchd trampoline, for a
        host layer whose launcher injects the API credentials. The reconciler reads
        VIKUNJA_API_URL and VIKUNJA_API_TOKEN from its environment, so the launcher
        must export both. Empty runs the reconciler directly.
      '';
    };

    stateFile = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/Library/Application Support/mlx-cluster/maintenance-window-task";
      description = ''
        Holds the open window's task id, and nothing else. NOT a cluster-state
        marker: whether this host is clustered is asked of launchd and the link
        files on every tick. This file only answers "which task did I open"; an id
        whose task was deleted is forgotten on the next refresh, never a wrong
        hands-off verdict.
      '';
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/Library/Logs/mlx-cluster";
      description = "Directory for the agent's stdout/stderr. Every tick writes its decision here.";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0755 "${cfg.logDir}"
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0700 "$(dirname "${cfg.stateFile}")"
    '';

    launchd.user.agents.cluster-maintenance-window.serviceConfig = {
      Label = "dev.mlx-cluster.maintenance-window";
      # The named trampoline waits for /nix/store before it execs this vector.
      # The first pass runs at load, which can come before the store is mounted.
      ProgramArguments = launchdTrampolineArgs "cluster-maintenance-window" (
        cfg.launcherPrefix ++ [ (lib.getExe windowPkg) ]
      );
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
