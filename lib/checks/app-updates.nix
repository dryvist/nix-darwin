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
  # Every CustomSystemPreferences domain must be an absolute system path.
  systemWide = domains: builtins.all (d: pkgs.lib.hasPrefix "/Library/Preferences/" d) domains;
  prefs = workstation.system.defaults.CustomSystemPreferences;
in
assert systemWide [ "/Library/Preferences/com.apple.x" ];
assert !(systemWide [ "com.apple.x" ]);
assert builtins.all (
  c: systemWide (builtins.attrNames c.config.system.defaults.CustomSystemPreferences)
) (builtins.attrValues configs);
assert
  !(server.system.defaults.CustomSystemPreferences ? "/Library/Preferences/com.apple.commerce");
assert
  !(server.system.defaults.CustomSystemPreferences ? "/Library/Preferences/com.apple.SoftwareUpdate");
assert prefs."/Library/Preferences/com.apple.commerce".AutoUpdate;
assert prefs."/Library/Preferences/com.apple.SoftwareUpdate".AutomaticCheckEnabled;
assert prefs."/Library/Preferences/com.apple.SoftwareUpdate".AutomaticDownload;
assert prefs."/Library/Preferences/com.apple.SoftwareUpdate".AutomaticallyInstallAppUpdates;
assert !(workstation.environment.etc ? "sudoers.d/app-updates");
assert !(workstation.launchd.user.agents ? app-store-upgrade);
assert !(server.launchd.user.agents ? app-store-upgrade);
pkgs.runCommand "check-app-updates" { } "touch $out"
