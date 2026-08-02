# WindowServer Performance Monitor
#
# System-level LaunchDaemon that captures WindowServer performance metrics
# to JSONL every 15 seconds. Runs as root to access system-level compositor
# state and GPU metrics.
#
# Log: /var/log/ws-monitor/ws-monitor.jsonl

{ lib, pkgs, ... }:

let
  logDir = "/var/log/ws-monitor";

  label = "dev.local.ws-monitor";

  monitorScript = pkgs.writeShellApplication {
    name = "ws-monitor";
    runtimeInputs = with pkgs; [ jq ];
    text = builtins.readFile ./scripts/ws-monitor.sh;
  };
in
{
  # Ensure log directory exists with correct permissions before launchd opens stderr.
  #
  # Also retires any previously-installed label for this daemon. nix-darwin
  # COPIES daemon plists as regular files rather than symlinking them, so a
  # label change installs the new plist and leaves the old file in place, where
  # launchd loads it again at boot and two copies of the monitor run. Booting it
  # out and deleting the file is the only thing that actually retires it.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /bin/mkdir -p "${logDir}"
    /bin/chmod 755 "${logDir}"

    for stale in /Library/LaunchDaemons/*ws-monitor.plist; do
      [ -f "$stale" ] || continue
      [ "$stale" = "/Library/LaunchDaemons/${label}.plist" ] && continue
      /bin/launchctl bootout system "$stale" 2>/dev/null || true
      /bin/rm -f "$stale"
      echo "[ws-monitor] retired stale daemon plist: $stale"
    done
  '';

  # System-level LaunchDaemon — runs as root for full system visibility
  launchd.daemons.ws-monitor = {
    serviceConfig = {
      Label = label;
      ProgramArguments = [ "${monitorScript}/bin/ws-monitor" ];
      StartInterval = 15;
      RunAtLoad = true;
      StandardErrorPath = "${logDir}/ws-monitor.err.log";
    };
  };
}
