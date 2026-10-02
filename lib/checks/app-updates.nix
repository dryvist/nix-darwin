{ pkgs, configs }:
let
  hosts = import ../hosts.nix;
  profiles = import ../host-profiles.nix { inherit (pkgs) lib; };
  host = pkgs.lib.recursiveUpdate profiles.workstation hosts.mac-studio;
  server =
    (configs.${host.hostName}.extendModules {
      specialArgs.hostConfig = host // {
        isServer = true;
        homebrew = host.homebrew // {
          enableWorkstationApps = false;
        };
      };
    }).config;
  workstation = configs.${hosts.macbook-m4.hostName}.config;
  prefs = workstation.system.defaults.CustomSystemPreferences;
in
assert !(server.system.defaults.CustomSystemPreferences ? "com.apple.commerce");
assert !(server.system.defaults.CustomSystemPreferences ? "com.apple.SoftwareUpdate");
assert prefs."com.apple.commerce".AutoUpdate;
assert prefs."com.apple.SoftwareUpdate".AutomaticCheckEnabled;
assert prefs."com.apple.SoftwareUpdate".AutomaticDownload;
assert prefs."com.apple.SoftwareUpdate".AutomaticallyInstallAppUpdates;
assert !(workstation.environment.etc ? "sudoers.d/app-updates");
assert !(workstation.launchd.user.agents ? app-store-upgrade);
assert !(server.launchd.user.agents ? app-store-upgrade);
pkgs.runCommand "check-app-updates" { } "touch $out"
