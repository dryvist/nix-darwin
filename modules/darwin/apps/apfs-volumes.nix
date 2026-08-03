# APFS Volumes Configuration Module (Darwin)
#
# Ensures dedicated APFS volumes exist on the internal container: for logical
# separation of large data sets (AI model caches, container data) and, where a
# quota is given, to bound one that would otherwise grow without limit.
# Volumes are logical partitions that share the container's free space
# dynamically — no pre-allocation, no min/max. This makes disk usage easy to
# see and clean per data set without carving fixed partitions.
#
#   programs.apfsVolumes = {
#     enable = true;
#     apfsContainer = "disk3";              # Find with: diskutil apfs list
#     volumes = [
#       "HuggingFace"                         # no ceiling: shares free space
#       { name = "Streams"; quota = "100g"; } # hard ceiling
#     ];
#   };
#
# `quota` is a MAXIMUM, not a reservation: the volume consumes only what it
# actually uses and still shares the container's free space — it simply cannot
# grow past the ceiling. It applies at CREATE time only; changing the value does
# not resize an existing volume (use `diskutil apfs resizeVolume` by hand).
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
#
# That edge case is harmless for a volume used as a cache, but NOT for one
# holding live data: re-creating it yields a second, EMPTY volume mounted at the
# same path while the populated one sits unmounted, so a writer that only checks
# "is something mounted here?" silently writes into the empty twin. A consumer
# of a quota'd volume should therefore require a sentinel file it wrote itself,
# not merely a mount, before treating the path as its data directory.

{
  lib,
  config,
  ...
}:

let
  cfg = config.programs.apfsVolumes;

  # A volume entry is either a bare name or { name; quota; }. coercedTo below
  # normalises the bare-string form, so this only ever sees the attrset.
  volumeModule = {
    options = {
      name = lib.mkOption {
        type = lib.types.strMatching "^[A-Za-z0-9._-]+$";
        description = "Volume name. Mounts at /Volumes/<name>.";
        example = "Streams";
      };

      quota = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "^[0-9]+[bkmgtBKMGT]$");
        default = null;
        description = ''
          Hard size ceiling passed to `diskutil apfs addVolume -quota`. A
          MAXIMUM, not a reservation: the volume consumes only what it uses and
          still shares the container's free space, it just cannot exceed this.

          Applied at CREATE time only — changing it does not resize an existing
          volume. null means no ceiling.
        '';
        example = "100g";
      };
    };
  };

  mkVolumeDaemon = volume: {
    "apfs-volume-${lib.toLower volume.name}" = {
      serviceConfig = {
        Label = "com.nix-darwin.apfs-volume-${lib.toLower volume.name}";
        ProgramArguments = [
          "/usr/sbin/diskutil"
          "apfs"
          "addVolume"
          cfg.apfsContainer
          "APFS"
          volume.name
        ]
        ++ lib.optionals (volume.quota != null) [
          "-quota"
          volume.quota
        ];
        # Run only while the volume's mount path is absent; stops once created.
        KeepAlive.PathState."/Volumes/${volume.name}" = false;
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
      type = lib.types.listOf (
        lib.types.coercedTo (lib.types.strMatching "^[A-Za-z0-9._-]+$") (name: { inherit name; }) (
          lib.types.submodule volumeModule
        )
      );
      default = [ ];
      description = ''
        APFS volumes to ensure exist under apfsContainer. Each mounts at
        /Volumes/<name>. An entry is either a bare name (no size ceiling) or an
        attrset with an optional `quota`.
      '';
      example = [
        "HuggingFace"
        {
          name = "Streams";
          quota = "100g";
        }
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
