# Evaluates every host's full system derivation (`system.build.toplevel`).
# Host evaluation reads files from fetched Darwin sources, so this needs a
# Darwin builder; the macOS CI job builds it after the Home Manager build.
#
{
  pkgs,
  configs,
}:
let
  drvPaths = pkgs.lib.mapAttrsToList (
    _: cfg: builtins.unsafeDiscardStringContext cfg.config.system.build.toplevel.drvPath
  ) configs;
in
assert configs != { };
assert pkgs.lib.all (
  cfg:
  pkgs.lib.hasInfix "launchctl bootout system/org.nixos.darwin-auto-upgrade" cfg.config.system.activationScripts.postActivation.text
) (builtins.attrValues configs);
builtins.deepSeq drvPaths (pkgs.runCommand "check-system-eval" { } "touch $out")
