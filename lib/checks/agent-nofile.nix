{
  pkgs,
  darwin,
  src,
  configs ? { },
}:
let
  inherit (pkgs.lib)
    attrValues
    attrNames
    any
    elem
    filter
    hasInfix
    mapAttrsToList
    ;

  nofile = import ../agent-nofile.nix;
  codexTarget = builtins.unsafeDiscardStringContext "${pkgs.codex}/bin/codex";
  codexLauncherTargets =
    hostConfig:
    mapAttrsToList (
      _: homeConfig:
      let
        codexPackage = homeConfig.programs.codex.package or null;
        launcherPackages = filter (package: package.name == "agent-cli-launchers") homeConfig.home.packages;
        launchers = if launcherPackages == [ ] then [ ] else (builtins.head launcherPackages).launchers;
      in
      codexPackage == pkgs.codex
      && elem codexPackage homeConfig.home.packages
      && any (
        launcher:
        hasInfix codexTarget launcher.text
        && hasInfix "ulimit -S -n ${toString nofile} || exit 1" launcher.text
        && hasInfix "ulimit -H -n ${toString nofile} || exit 1" launcher.text
      ) launchers
      && !(any (launcher: hasInfix "/opt/homebrew/bin/codex" launcher.text) launchers)
    ) (hostConfig.config.home-manager.users or { });
  codexLaunchersValid =
    attrNames configs == [ ]
    || builtins.all (
      hostConfig:
      let
        targets = codexLauncherTargets hostConfig;
      in
      targets != [ ] && builtins.all (valid: valid) targets
    ) (attrValues configs);

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
assert
  codexLaunchersValid || throw "Codex launcher must execute the installed nixpkgs codex package.";
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
