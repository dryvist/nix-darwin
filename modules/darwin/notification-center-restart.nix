# Daily NotificationCenter restart: its memory and CPU grow over days of uptime and add
# WindowServer load. launchd respawns the process within a second.
#
# shortcut: a fixed daily restart rather than a fix for the growth; upgrade when the cause is
# found.
_: {
  launchd.user.agents.notification-center-restart.serviceConfig = {
    Label = "com.nix-darwin.notification-center-restart";
    ProgramArguments = [
      "/usr/bin/killall"
      "NotificationCenter"
    ];
    RunAtLoad = false;
    ProcessType = "Background";
    StartCalendarInterval = [
      {
        Hour = 3;
        Minute = 41;
      }
    ];
  };
}
