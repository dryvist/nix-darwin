# mac-studio — M4 Max / 128 GB headless network server for the homelab.
#
# Serving detail lives in nix-ai's validated model catalog
# (modules/mlx/catalog-data.nix): parser stacks, chat-template kwargs, and
# per-class flag profiles. The role map picks entries + classes; this host sets
# host-scoped runtime posture. Add or fix serve args in the catalog, not here.
let
  # THE proxy admission ceiling for this host. Per-model concurrency comes
  # from the role map (modelConcurrencyLimits); this is the upper bound the
  # proxy advertises.
  #
  # MLX's published admission limit is separate from the active GPU profile.
  # dryvist/tofu-proxmox publishes serving.mlx_llm_concurrency; this flake is
  # hermetic, so CI checks this literal against that field.
  serveConcurrency = 2;
in
{
  # Network identity. `system` omitted (mkHost defaults to aarch64-darwin).
  hostName = "jevans-ms";

  # Headless, always-on LAN inference/batch server. Drives server-class macOS
  # defaults (hosts/common/default.nix) and nix-home's server preset.
  class = "server";
  # Logical roles, catalog selection and per-model concurrency come from the
  # role map by host class (hosts/common/role-map.nix).

  mlx = {
    # Catalog selection, preload, per-model concurrency and the resident-worker
    # count derive from the role map (hosts/common/role-map.nix); the host adds
    # only runtime posture. The OCR model unloads after 600 s idle.
    catalog.unlimited-ocr.tweaks.ttl = 600;

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;

    # Server host: no group swap, no global idle eviction (per-class unloads
    # come from the catalog). A blanket TTL would make each resident brain pay
    # a 60-120 s cold start after any quiet period.
    proxy = {
      groupSwap = false;
      idleTtl = 0;
      # Advertised admission AND the worker's --decode/--prompt-concurrency
      # both derive from this one number (nix-ai effectiveConcurrency).
      concurrencyLimit = serveConcurrency;
    };

    # Clustered mode: the MacBook Pro is rank 0, coordinator, and HTTP
    # endpoint. This Studio is rank 1, worker, adding memory to the model.
    # Standalone serving above remains configured while detached.
    clusterMode = {
      # The coordinator drives this rank over SSH when joining the pair.
      enable = true;
      role = "worker";
      quiesce.launchdLabels = [
        "dev.mlx-model-server"
        "dev.mlx-model-server.mimo-9b"
      ];
      # Catalog-selected cluster model, identical on both ranks. The expert-pruned
      # REAP-50 build (~98 GB, glm4_moe) halves the per-rank shard to ~49 GB
      # so it fits under the cluster wired ceiling with real KV headroom; the
      # full 198 GB GLM-4.7-4bit (module default) is reserved for supervised
      # sessions until the ceiling values are validated.
      # shardMemoryMb (the memory-headroom rank-start precondition) is set once
      # for both ranks in hosts/common/cluster-wired-limit.nix, from a measured
      # shard size. Change it there alongside this key.
      modelCatalogKey = "glm47-reap50";
    };
  };

  # OrbStack stays OFF — this host uses the Apple `container` runtime, not
  # OrbStack. The ContainerData volume is still created (apfsVolumes below).
  orbstack.enable = false;

  # Same dedicated APFS volumes as the workstation, created identically.
  # Container id confirmed via `diskutil apfs list` (single 4TB internal).
  apfsContainer = "disk3";
  apfsVolumes = [
    "HuggingFace"
    "ContainerData"
  ];
}
