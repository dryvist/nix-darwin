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
    # The default 100 MB ring holds about 4 s under load; stalls last 16-65 s.
    /usr/bin/tailspin set buffer-size 1024 || true
  '';

  # Interactive: without it launchd runs the loop at utility QoS, which macOS throttles first
  # under thermal pressure, so a late tick would measure this daemon instead of the machine.
  launchd.daemons.ws-monitor.serviceConfig = {
    Label = label;
    ProcessType = "Interactive";
    ProgramArguments = launchdTrampolineArgs "ws-monitor" [ "${monitorScript}/bin/ws-monitor" ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/dev/null";
    StandardErrorPath = "${logDir}/ws-monitor.err.log";
  };
}
