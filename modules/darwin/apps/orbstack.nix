# OrbStack Configuration Module (Darwin)
#
# Manages macOS-specific OrbStack configuration:
# - System-level application installation (optional)
# - Background runner (starts the engine on login without the UI)
#
# The dedicated ContainerData APFS volume is created by
# modules/darwin/apps/apfs-volumes.nix (shared across hosts). OrbStack only
# consumes it: hosts/<host>/home.nix symlinks the App Group Container onto the
# volume with mkOutOfStoreSymlink:
#   home.file."Library/Group Containers/HUAQ24HBR6.dev.orbstack".source =
#     config.lib.file.mkOutOfStoreSymlink "/Volumes/ContainerData";
#
# Installation Patterns:
#
# 1. SYSTEM-LEVEL (Recommended for single-user machines):
#    programs.orbstack = { enable = true; package.enable = true; };
#    Pros: Machine-wide service, integrates with nix-darwin
#    Cons: TCC permissions may reset on rebuilds (requires re-granting)
#    App location: /Applications/Nix Apps/OrbStack.app
#
# 2. PER-USER (For multi-user machines or when TCC stability is critical):
#    programs.orbstack = { enable = true; package.enable = false; };
#    plus home.packages = [ pkgs.orbstack ]; in hosts/<host>/home.nix
#    Pros: With copyApps, provides stable paths for TCC permissions
#    App location: ~/Applications/Home Manager Apps/OrbStack.app
#
# Note: OrbStack doesn't natively support custom data directories, so the
# volume is wired in via the Group Container symlink rather than a data-dir option.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.orbstack;
in
{
  options.programs.orbstack = {
    enable = lib.mkEnableOption "OrbStack configuration";

    package = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Install OrbStack as a system-level application.

          When enabled: App installed to /Applications/Nix Apps/OrbStack.app
          When disabled: The package is not installed by this module. It is recommended to install via home.packages for stable TCC permissions.

          See module documentation for detailed comparison of installation patterns.
        '';
      };
    };

    background = {
      enable = lib.mkEnableOption "OrbStack background runner (starts on user login without UI)";
      package = lib.mkOption {
        type = lib.types.str;
        default =
          if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew/bin/orb" else "/usr/local/bin/orb";
        description = ''
          Path to the 'orb' binary used to start the background engine.
          Defaults to the Apple Silicon Homebrew prefix (/opt/homebrew) on arm64
          and Intel's /usr/local on x86_64.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Install OrbStack system-wide if package.enable is true
    environment.systemPackages = lib.mkIf cfg.package.enable [ pkgs.orbstack ];

    # The ContainerData APFS volume is created by modules/darwin/apps/apfs-volumes.nix
    # (shared across hosts); OrbStack only consumes it via the home-manager symlink.

    # Launchd user agent to start OrbStack in background on login
    launchd.user.agents.orbstack-background = lib.mkIf cfg.background.enable {
      serviceConfig = {
        Label = "com.nix-darwin.orbstack-background";
        ProgramArguments = [
          cfg.background.package
          "start"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
      };
    };
  };
}
