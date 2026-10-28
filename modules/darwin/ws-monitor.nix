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

  # LaunchDaemons run as root, with scheduling and I/O priority kept low.
  launchd.daemons.ws-monitor.serviceConfig = {
    Label = label;
    ProgramArguments = launchdTrampolineArgs "ws-monitor" [ "${monitorScript}/bin/ws-monitor" ];
    RunAtLoad = true;
    KeepAlive = true;
    Nice = 10;
    LowPriorityIO = true;
    ProcessType = "Background";
    StandardOutPath = "/dev/null";
    StandardErrorPath = "${logDir}/ws-monitor.err.log";
  };
}
