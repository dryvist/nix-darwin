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
#
# Inlined rather than a separate .sh file, matching
# ../../modules/darwin/hm-activation-assert.nix: the option, its ordering, and
# the shell it runs live in one declared, reviewable place. Reads
# $newGenPath, $HOME and $DRY_RUN_CMD from the activation environment.

{ lib, ... }:
{
  home.activation.clearStrayLinkTargets = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # `home-files` is a one-level symlink into the store; plain readlink resolves it
    # under both GNU and BSD userlands (BSD readlink has no -e). home-manager's
    # activation script runs under `set -eu`, so guard the readlink and skip the
    # sweep rather than aborting the whole activation if it ever comes back empty.
    strayNewGenFiles="$(readlink "$newGenPath/home-files" 2>/dev/null || true)"

    if [ -n "$strayNewGenFiles" ] && [ -d "$strayNewGenFiles" ]; then
      while IFS= read -r -d ''' straySource; do
        strayTarget="$HOME/''${straySource#"$strayNewGenFiles"/}"
        [ -L "$strayTarget" ] || continue

        strayLink="$(readlink "$strayTarget")"
        # A link into a home-manager generation is home-manager's own; it relinks it.
        case "$strayLink" in
        /nix/store/*-home-manager-files/*) continue ;;
        esac

        echo "clearing unmanaged symlink in the way of home-manager: $strayTarget -> $strayLink" >&2
        $DRY_RUN_CMD rm -f "$strayTarget"
      done < <(find "$strayNewGenFiles" \( -type f -o -type l \) -print0)
    fi
  '';
}
