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
in
assert !(server.launchd.user.agents ? app-store-upgrade);
assert !(server.launchd.user.agents ? app-update-health);
assert !(server.environment.etc ? "sudoers.d/app-updates");
assert !(server.system.defaults.CustomSystemPreferences ? "com.apple.commerce");
assert workstation.system.defaults.CustomSystemPreferences."com.apple.commerce".AutoUpdate;
assert workstation.launchd.user.agents.app-store-upgrade.serviceConfig.RunAtLoad;
assert !(workstation.launchd.user.agents ? app-update-health);
assert workstation.launchd.user.agents.app-store-upgrade.serviceConfig.ProgramArguments == [
  "/usr/bin/sudo"
  "-n"
  (pkgs.lib.getExe pkgs.mas)
  "update"
  "--inaccurate"
  "--check-min-os"
];
assert workstation.launchd.user.agents.brew-upgrade.serviceConfig.ProgramArguments == [
  "/opt/homebrew/bin/brew"
  "upgrade"
  "--greedy"
];
pkgs.runCommand "check-app-updates" { } ''
  /usr/sbin/visudo -c -f ${
    pkgs.writeText "app-updates-sudoers" workstation.environment.etc."sudoers.d/app-updates".text
  }
  touch $out
''
