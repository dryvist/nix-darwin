# macOS Screen Sharing (VNC), enabled by default so remote recovery after a
# reboot doesn't need physical console access.
#
# nix-darwin has no first-class `services.screenSharing`-style option (checked
# the nix-darwin-26.05 module tree — nothing references
# `com.apple.screensharing`), so this follows the same shape as
# programs.gitApfsVolume: a writeShellApplication invoked from
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

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Enabling macOS Screen Sharing..."
      ${lib.getExe enablePkg}
    '';
  };
}
