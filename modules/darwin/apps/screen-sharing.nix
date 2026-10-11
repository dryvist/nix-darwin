# macOS Screen Sharing (VNC). Enabled hosts get the service started so remote
# recovery after a reboot doesn't need physical console access; every other
# host has it disabled and stopped on each activation.
#
# nix-darwin has no first-class `services.screenSharing`-style option (checked
# the nix-darwin-26.05 module tree — nothing references
# `com.apple.screensharing`), so a writeShellApplication invoked from
# system.activationScripts.postActivation runs `launchctl enable` +
# `launchctl kickstart` against the system's built-in
# com.apple.screensharing launchd daemon. Plain Screen Sharing only — this
# does not turn on Remote Management (ARD) or set a control password.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.screenSharing;
  enablePkg = pkgs.writeShellApplication {
    name = "screen-sharing-enable";
    text = builtins.readFile ./scripts/screen-sharing.sh;
  };
in
{
  options.programs.screenSharing.enable = lib.mkEnableOption "macOS Screen Sharing (VNC) launchd service";

  # When off, every activation disables and stops the service, so a toggle in
  # System Settings does not persist across rebuilds.
  config.system.activationScripts.postActivation.text = lib.mkAfter (
    if cfg.enable then
      ''
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Enabling macOS Screen Sharing..."
        ${lib.getExe enablePkg}
      ''
    else
      ''
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Disabling macOS Screen Sharing..."
        /bin/launchctl disable system/com.apple.screensharing
        /bin/launchctl bootout system/com.apple.screensharing 2>/dev/null || true
      ''
  );
}
