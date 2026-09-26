# Evaluates every host's full system derivation (`system.build.toplevel`).
# Evaluation needs no Darwin builder, so this runs in the Linux
# `nix flake check`.
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
