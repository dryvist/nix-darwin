# APFS Volumes Configuration Module (Darwin)
#
# Ensures dedicated APFS volumes exist on the internal container, purely for
# logical separation of large data sets (AI model caches, container data).
# Volumes are logical partitions that share the container's free space
# dynamically — no pre-allocation, no quota, no min/max. This makes disk
# usage easy to see and clean per data set without carving fixed partitions.
#
#   programs.apfsVolumes = {
#     enable = true;
#     apfsContainer = "disk3";              # Find with: diskutil apfs list
#     volumes = [ "HuggingFace" "ContainerData" ];
#   };
#
# Native, no wrapper script: macOS exposes no declarative APFS-volume
# primitive, so `diskutil apfs addVolume` is invoked directly from a launchd
# daemon. It is not idempotent — a re-run on an already-present volume exits
# non-zero harmlessly (existing APFS volumes auto-mount at boot), so
# RunAtLoad + LaunchOnlyOnce creates the volume once and no-ops thereafter.

{
  lib,
  config,
  ...
}:

let
  cfg = config.programs.apfsVolumes;

  mkVolumeDaemon = name: {
    "apfs-volume-${lib.toLower name}" = {
      serviceConfig = {
        Label = "com.nix-darwin.apfs-volume-${lib.toLower name}";
        ProgramArguments = [
          "/usr/sbin/diskutil"
          "apfs"
          "addVolume"
          cfg.apfsContainer
          "APFS"
          name
        ];
        RunAtLoad = true;
        LaunchOnlyOnce = true;
        UserName = "root";
        GroupName = "wheel";
      };
    };
  };
in
{
  options.programs.apfsVolumes = {
    enable = lib.mkEnableOption "dedicated APFS volumes for logical data separation";

    apfsContainer = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        APFS container identifier where the volumes are created.
        Find yours with: diskutil apfs list
        Usually "disk3" on Apple Silicon Macs with a single internal store.
      '';
      example = "disk3";
    };

    volumes = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "^[A-Za-z0-9._-]+$");
      default = [ ];
      description = ''
        APFS volume names to ensure exist under apfsContainer.
        Each mounts at /Volumes/<name>.
      '';
      example = [
        "HuggingFace"
        "ContainerData"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.volumes == [ ] || cfg.apfsContainer != "";
        message = "programs.apfsVolumes.apfsContainer must be set. Find yours with: diskutil apfs list";
      }
    ];

    launchd.daemons = lib.mkMerge (map mkVolumeDaemon cfg.volumes);
  };
}
