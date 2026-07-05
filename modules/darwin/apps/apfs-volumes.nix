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
# Native, no wrapper script and no inline shell: macOS exposes no declarative
# APFS-volume primitive, so `diskutil apfs addVolume` is invoked directly from a
# launchd daemon. `addVolume` is NOT idempotent (APFS allows duplicate volume
# names), so idempotency is enforced declaratively by launchd itself:
# KeepAlive.PathState gates the job on the volume's mount path being ABSENT.
# launchd starts the job only while /Volumes/<name> does not exist, and stops it
# the instant addVolume creates + mounts the volume — so an existing volume
# never triggers a second create. No RunAtLoad (that would run unconditionally).
# Edge case: a manually-unmounted existing volume looks absent and could be
# re-created; APFS data volumes auto-mount at boot, so this is not hit in normal
# operation.

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
        # Run only while the volume's mount path is absent; stops once created.
        KeepAlive.PathState."/Volumes/${name}" = false;
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
