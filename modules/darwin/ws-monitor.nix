# System-level WindowServer stall monitor and capture.

{
  lib,
  pkgs,
  launchdTrampolineArgs,
  ...
}:

let
  logDir = "/var/log/ws-monitor";
  captureDir = "${logDir}/captures";
  label = "dev.local.ws-monitor";

  monitorScript = pkgs.writeShellApplication {
    name = "ws-monitor";
    runtimeInputs = with pkgs; [ jq ];
    text = builtins.readFile ./scripts/ws-monitor.sh;
  };
in
{
  # Prepare writable capture paths once per activation. Safe to repeat.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /bin/mkdir -p "${logDir}" "${captureDir}"
    /bin/chmod 755 "${logDir}" "${captureDir}"
  '';

  # Runs as root at normal scheduling and I/O priority: a late tick must measure the machine,
  # not this daemon's own throttling.
  launchd.daemons.ws-monitor.serviceConfig = {
    Label = label;
    ProgramArguments = launchdTrampolineArgs "ws-monitor" [ "${monitorScript}/bin/ws-monitor" ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/dev/null";
    StandardErrorPath = "${logDir}/ws-monitor.err.log";
  };
}
