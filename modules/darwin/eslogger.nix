# Endpoint Security process lifecycle events, written to the unified log.
#
# eslogger is Apple's Endpoint Security client. It must run as root and needs
# Full Disk Access granted to /usr/bin/eslogger itself, so the daemon executes
# it directly, with no wrapper. --oslog writes each event to the unified log
# (default subsystem com.apple.eslogger, category events). Nothing is written
# to a file, so nothing is rotated. launchd discards stdout and stderr.
{ ... }:

{
  launchd.daemons.eslogger.serviceConfig = {
    Label = "dev.local.eslogger";
    ProgramArguments = [
      "/usr/bin/eslogger"
      "exec"
      "exit"
      "--oslog"
    ];
    RunAtLoad = true;
    KeepAlive = true;
  };
}
