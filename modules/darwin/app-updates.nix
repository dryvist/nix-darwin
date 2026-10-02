{ lib, hostConfig, ... }:
let
  workstation = hostConfig.homebrew.enableWorkstationApps;
in
{
  # Keyed by absolute path: a bare domain is written as root into /var/root, not system-wide.
  # macOS performs the App Store updates itself; these are its native preferences.
  system.defaults.CustomSystemPreferences = lib.mkIf workstation {
    "/Library/Preferences/com.apple.commerce".AutoUpdate = true;
    "/Library/Preferences/com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      AutomaticDownload = true;
      AutomaticallyInstallAppUpdates = true;
    };
  };
}
