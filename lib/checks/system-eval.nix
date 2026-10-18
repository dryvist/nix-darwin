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
builtins.deepSeq drvPaths (pkgs.runCommand "check-system-eval" { } "touch $out")
