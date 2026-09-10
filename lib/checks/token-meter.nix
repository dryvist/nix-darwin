# Token Meter policy belongs to the shared primary-user configuration: every
# registered Mac runs the service and native menu-bar companion. This needs a
# Darwin-side assertion because nix-ai does not know this repository's host
# registry or which Home Manager user is interactive.
{
  pkgs,
  configs,
  userConfig,
}:
let
  inherit (pkgs.lib) mapAttrsToList;

  tokenMeterFor =
    hostName: cfg:
    let
      users = cfg.config.home-manager.users or { };
      primaryUser =
        users.${userConfig.user.name}
          or (throw "Token Meter regression: ${hostName} has no primary Home Manager user ${userConfig.user.name}");
    in
    primaryUser.programs.token-meter;

  violations = mapAttrsToList (
    hostName: cfg:
    let
      tokenMeter = tokenMeterFor hostName cfg;
    in
    if tokenMeter.disabled == false && tokenMeter.menuBar == true then
      null
    else
      "${hostName}: expected programs.token-meter.disabled = false and menuBar = true"
  ) configs;

  failures = builtins.filter (violation: violation != null) violations;
in
assert
  failures == [ ]
  || throw "Token Meter opt-in regression:\n${builtins.concatStringsSep "\n" failures}";
pkgs.runCommand "check-token-meter" { } ''
  echo "Token Meter is enabled with its menu-bar companion on every registered Mac"
  touch $out
''
