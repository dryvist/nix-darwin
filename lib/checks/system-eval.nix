# Evaluates every host's full system derivation. The macOS CI build only
# covers the Home Manager closure, so a system option that is required but
# unset would otherwise surface only at `darwin-rebuild` time. Evaluation needs
# no Darwin builder, so this runs in the Linux `nix flake check`.
#
# `hostLayer` stubs the values a host layer outside this repository must set.
# A new required option with no default fails this check until it is stubbed
# here and set in that host layer.
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
