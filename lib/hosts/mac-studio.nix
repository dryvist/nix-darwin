# mac-studio — M4 Max / 128 GB headless network server for the homelab.
#
# Serving detail lives in nix-ai's validated model catalog
# (modules/mlx/catalog-data.nix): parser stacks, chat-template kwargs, and
# per-class flag profiles. The role map picks entries + classes; this host sets
# host-scoped runtime posture. Add or fix serve args in the catalog, not here.
let
  # The local proxy's fallback admission ceiling. Per-model worker and
  # admission limits below this default are projected from the role map.
  #
  # MLX's published admission limit is separate from the active GPU profile.
  # dryvist/tofu-proxmox publishes serving.mlx_llm_concurrency; this flake is
  # hermetic, so CI checks this literal against that field.
  serveConcurrency = 2;
  singleSequence = 1;
in
{
  # Network identity. `system` omitted (mkHost defaults to aarch64-darwin).
  hostName = "jevans-ms";

  # Headless, always-on LAN inference/batch server. Drives server-class macOS
  # defaults (hosts/common/default.nix) and nix-home's server preset.
  class = "server";
  # Logical roles, catalog selection and per-model concurrency come from the
  # role map by host class (hosts/common/role-map.nix).
  # The Studio keeps one active sequence per resident model. Its serving gate
  # separately admits at most one active plus one waiting request.
  modelConcurrency = {
    qwen38-27b = singleSequence;
    mimo-9b = singleSequence;
  };

  mlx = {
    # Keep only the two declared resident models. The separate Qwen worker is
    # the sole router-facing model; no other catalog model can load on demand.
    catalog.unlimited-ocr.enable = false;

    # Two resident workers at 32 GiB each leave room for the session reserve
    # under the existing 100 GiB wired ceiling. MLX treats this as a sizing
    # guideline, so the configured ceiling still requires a measured soak.
    memoryHardLimitGb = 32;

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

  # Ghostty and the same AI desktop apps as the workstation profile. mkHost
  # merges this over the server profile.
  homebrew = {
    ghostty = true;
    ai = {
      antigravityDesktop = true;
      antigravityIde = true;
      chatgptDesktop = true;
      claudeDesktop = true;
      codexDesktop = true;
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
