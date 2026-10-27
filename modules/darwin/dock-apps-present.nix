# Report missing paths from the configured Dock tiles after home-manager has
# applied. This stays warn-only so an absent app never interrupts activation;
# see docs/ACTIVATION-SCRIPTS-RULES.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  dockApps = config.system.defaults.dock.persistent-apps or null;

  dockPaths = lib.concatMap (
    tile:
    lib.optional (
      (tile.tile-data.file-data._CFURLString or null) != null
    ) tile.tile-data.file-data._CFURLString
  ) (lib.optionals (dockApps != null) dockApps);

  dockAppsPresent = pkgs.writeShellApplication {
    name = "dock-apps-present";
    text = builtins.readFile ./scripts/dock-apps-present.sh;
  };
in
{
  system.activationScripts.postActivation.text = lib.mkOrder 1700 ''
    ${lib.getExe dockAppsPresent} ${lib.escapeShellArgs dockPaths} || true
  '';
}
