{ lib, hostConfig, ... }:
let
  workstation = hostConfig.homebrew.enableWorkstationApps;
in
{
  # macOS performs the App Store updates itself; these are its native preferences.
  system.defaults.CustomSystemPreferences = lib.mkIf workstation {
    "com.apple.commerce".AutoUpdate = true;
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      AutomaticDownload = true;
      AutomaticallyInstallAppUpdates = true;
    };
  };
}
