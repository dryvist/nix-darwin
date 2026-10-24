{
  pkgs,
  darwin,
  src,
}:
let
  nofile = import ../agent-nofile.nix;
  render =
    enabled:
    (darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        (src + "/modules/darwin/system-limits.nix")
        {
          nix.enable = false;
          system.stateVersion = 6;
          system.resourceLimits.enable = enabled;
        }
      ];
    }).config;
  enabled = render true;
  disabled = render false;
  env = enabled.launchd.daemons.set-resource-limits.serviceConfig.EnvironmentVariables;
  activation = enabled.system.activationScripts.script.text;
in
assert nofile > 0;
assert env.LAUNCHCTL_MAXFILES_SOFT == toString nofile;
assert env.LAUNCHCTL_MAXFILES_HARD == toString nofile;
assert pkgs.lib.hasInfix "LAUNCHCTL_MAXFILES_SOFT=${pkgs.lib.escapeShellArg (toString nofile)}"
  activation;
assert pkgs.lib.hasInfix "LAUNCHCTL_MAXFILES_HARD=${pkgs.lib.escapeShellArg (toString nofile)}"
  activation;
assert !(pkgs.lib.hasInfix "system-limits-apply" disabled.system.activationScripts.script.text);
pkgs.runCommand "check-agent-nofile" { } ''
  touch "$out"
''
