# Cribl Edge Deadman Watchdog
#
# A LaunchDaemon that posts a heartbeat to one or more Healthchecks endpoints
# every `interval` seconds — but only when the Cribl Edge daemon on this host
# is alive AND its log file shows recent writes. Acts as a deadman's switch:
# if the Mac is hard-down, the daemon dies, or the daemon wedges, the pings
# stop and the upstream Healthchecks instance fires its alert.
#
# Why a separate module from programs.cribl-edge:
#   Coupling them would risk a bug in the cribl-edge module taking the
#   watchdog down with it — the whole point of the watchdog is to observe
#   cribl-edge as a black box. They share a host but no Nix-level state.
#
# Two URLs are intentionally supported (one external SaaS, one self-hosted)
# so the alerting infrastructure itself is redundant — losing either does not
# leave the operator blind. Either may be unset; an unset URL means the
# corresponding upstream deadman simply was never armed.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.cribl-edge-watchdog;

  watchdogScript = pkgs.writeShellApplication {
    name = "cribl-edge-watchdog";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];
    text = ''
      exec ${./scripts/cribl-edge-watchdog.sh} \
        "${cfg.secretsFile}" \
        "${cfg.daemonLabel}" \
        "${cfg.daemonLogFile}" \
        "${toString cfg.logMtimeThresholdSeconds}"
    '';
  };
in
{
  options.programs.cribl-edge-watchdog = {
    enable = lib.mkEnableOption "Cribl Edge deadman watchdog";

    secretsFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to a root-readable KEY=value file. Recognized keys:
          HEALTHCHECKS_IO_URL    — external SaaS check URL
          HEALTHCHECKS_LOCAL_URL — self-hosted check URL
        Either may be empty; both empty means the watchdog no-ops cleanly.
        Use the sops-nix rendered template:
          config.sops.templates."cribl-edge-watchdog.env".path
      '';
      example = "/run/secrets/rendered/cribl-edge-watchdog.env";
    };

    daemonLabel = lib.mkOption {
      type = lib.types.str;
      default = "com.nix-darwin.cribl-edge";
      description = "launchd label of the daemon whose liveness gates the heartbeat.";
    };

    daemonLogFile = lib.mkOption {
      type = lib.types.str;
      default = "/opt/cribl-data/log/cribl.log";
      description = ''
        Absolute path to the Cribl Edge log file. Used as a "doing work"
        liveness signal in addition to launchctl state — a launchctl-running
        daemon that has stopped writing logs is treated as wedged.
      '';
    };

    logMtimeThresholdSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = ''
        Maximum acceptable age of the daemon log file's mtime, in seconds.
        Older than this and the daemon is considered wedged (no heartbeat
        sent). Should be >= the heartbeat interval so a single quiet polling
        cycle does not look like a wedge.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = ''
        launchd StartInterval in seconds — how often the watchdog runs.
        Defaults to 300s (5 min). Tune in concert with the upstream
        Healthchecks "grace period" (e.g. ping every 5 min, alert after 15 min).
      '';
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log";
      description = "Directory for the watchdog's own stdout/stderr launchd logs.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.cribl-edge-watchdog = {
      serviceConfig = {
        Label = "com.nix-darwin.cribl-edge-watchdog";
        ProgramArguments = [ "${watchdogScript}/bin/cribl-edge-watchdog" ];
        # Run on a fixed interval rather than KeepAlive — this is a poll, not
        # a long-running daemon. RunAtLoad ensures the first ping happens
        # immediately after darwin-rebuild instead of waiting `interval` seconds.
        RunAtLoad = true;
        StartInterval = cfg.interval;
        # Run as root so the secrets file (root:wheel 0400) is readable.
        # The script makes no network changes and only POSTs to URLs from the
        # whitelist-parsed secrets file, so root privilege is contained.
        UserName = "root";
        GroupName = "wheel";
        StandardOutPath = "${cfg.logDir}/cribl-edge-watchdog.log";
        StandardErrorPath = "${cfg.logDir}/cribl-edge-watchdog.log";
      };
    };
  };
}
