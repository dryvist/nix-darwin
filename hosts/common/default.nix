# Shared darwin (system-level) configuration
#
# Imported by every host's default.nix. Holds host-agnostic system config and
# consumes registry parameters (networking.hostName, OrbStack). Host-specific
# system config — Cribl log sources, streamline-login lists, energy /
# appleSiliconTunables values — stays in hosts/<label>/default.nix.

{ lib, hostConfig, ... }:

{
  imports = [
    # Darwin system modules
    ../../modules/darwin/common.nix
  ];

  # Network hostname from the per-host registry.
  networking.hostName = hostConfig.hostName;

  # SSH/Remote Login — macOS Remote Login via launchd (Settings > General > Sharing).
  services.openssh.enable = true;

  programs = {
    # Custom file extensions recognized as tar.gz archives (Finder auto-extract
    # + shell autocomplete).
    file-extensions.enable = true;

    # --- OrbStack ---
    # Container runtime as a system-level application on a dedicated APFS volume.
    # Only configured when the host enables it (headless hosts may not).
    # package.enable = false: OrbStack is installed via Homebrew cask (greedy) in
    # modules/darwin/homebrew.nix — a real /Applications copy, so TCC permissions
    # (Docker socket, Linux VM) persist across darwin-rebuild rather than breaking
    # on every /nix/store path change.
    # background.enable = false: `orb start` exits 0 in <1s; KeepAlive=true was
    # throttle-respawning it into a runningboardd assertion flood. OrbStack.app
    # manages its own startup.
    orbstack = lib.mkIf hostConfig.orbstack.enable {
      enable = true;
      package.enable = false;
      background.enable = false;
      dataVolume = {
        enable = true;
        name = hostConfig.orbstack.containerVolume;
        apfsContainer = hostConfig.orbstack.apfsContainer;
      };
    };
  };
}
