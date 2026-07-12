# git APFS Volume — a dedicated 100 GiB-quota "git" volume on the internal
# container, created if absent on every Mac.
#
# Distinct from apfs-volumes.nix (free-space-sharing HuggingFace/ContainerData
# volumes: hardcoded container, no quota): this volume carries a hard 100 GiB
# quota and resolves its container at runtime from the booted root volume, so no
# disk identifier is hardcoded. Create-if-absent, no data migration.
#
# macOS exposes no declarative APFS-volume primitive, so creation goes through
# `diskutil apfs addVolume ... -quota 100g` in a writeShellApplication run once
# per activation. The script self-guards on `diskutil apfs list`, so re-runs
# after the volume exists are no-ops.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.gitApfsVolume;
  createPkg = pkgs.writeShellApplication {
    name = "git-apfs-volume-create";
    text = builtins.readFile ./scripts/git-apfs-volume.sh;
  };
in
{
  options.programs.gitApfsVolume.enable = lib.mkEnableOption ''dedicated 100 GiB-quota "git" APFS volume on the internal container'';

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Ensuring 'git' APFS volume (100g quota) exists on the internal container..."
      ${lib.getExe createPkg}
    '';
  };
}
