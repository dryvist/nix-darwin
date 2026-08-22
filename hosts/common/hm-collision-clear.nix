# Clear stray symlinks sitting at home-manager-managed paths.
#
# `home-manager.backupCommand` (lib/home-manager-defaults.nix) already resolves
# collisions with unmanaged REGULAR files. It cannot resolve a collision with an
# unmanaged SYMLINK: upstream's check-link-targets.sh gates both its backup
# branches on `! -L "$targetPath"`, so a symlink at a managed path falls through
# to the "would be clobbered" error and aborts `checkLinkTargets` — before
# `writeBoundary`, so no user file and no LaunchAgent plist is written at all.
# Setting `backupFileExtension` instead would not change this; that branch
# carries the same `! -L` gate.
#
# Same policy as backupCommand: the Nix store is the source of truth, so an
# unmanaged symlink in the way is removed, not preserved. Every removal is
# logged. Symlinks already pointing into a home-manager generation are left
# alone — those are the links home-manager relinks itself.

{ lib, ... }:
{
  home.activation.clearStrayLinkTargets = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
    builtins.readFile ./scripts/clear-stray-link-targets.sh
  );
}
