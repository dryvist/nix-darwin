# Evaluates every host's full system derivation (`system.build.toplevel`).
# Host evaluation reads files from fetched Darwin sources, so this needs a
# Darwin builder; the macOS CI job builds it after the Home Manager build.
#
# `hostLayer` stubs options that have no default here and are set by the
# consuming host configuration. A new such option must be stubbed here.
{
  pkgs,
  configs,
}:
let
  hostLayer = {
    services.clusterMaintenanceWindow.passwordSecret = "ci-stub#password";
  };

  drvPaths = pkgs.lib.mapAttrsToList (
    _: cfg:
    builtins.unsafeDiscardStringContext
      (cfg.extendModules { modules = [ hostLayer ]; }).config.system.build.toplevel.drvPath
  ) configs;
in
builtins.deepSeq drvPaths (pkgs.runCommand "check-system-eval" { } "touch $out")
