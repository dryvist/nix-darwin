# Home-Manager Default Settings
#
# Shared home-manager configuration used across all hosts.
# Import this in flake.nix modules sections.
#
# Usage in flake.nix:
#   let hmDefaults = import ./lib/home-manager-defaults.nix; in
#   { home-manager = hmDefaults; }

{
  # Use nixpkgs from the system flake (not a separate instance)
  # This inherits nixpkgs.config.allowUnfree from modules/darwin/common.nix
  useGlobalPkgs = true;

  # Install user packages to /etc/profiles instead of ~/.nix-profile
  useUserPackages = true;

  # Remove conflicting files/directories so home-manager can place its symlinks.
  # Nix store is the source of truth for all HM-managed files. Pre-existing
  # conflicting content (files not yet in the Nix store) is permanently deleted
  # without recovery — this is intentional. Previous HM generations can restore
  # managed symlinks but cannot restore pre-existing conflicting content.
  # `--` ensures paths starting with `-` are never treated as flags.
  #
  # This covers regular files only. Upstream gates both this branch and the
  # backupFileExtension branch on `! -L`, so an unmanaged SYMLINK at a managed
  # path still aborts checkLinkTargets — hosts/common/hm-collision-clear.nix
  # clears those before the collision check runs.
  backupCommand = "rm -rf --";
}
