# macbook-m4 — M4 Max / 128 GB workstation (self-serving: localhost
# clients only, keeps load off the network server).
{
  # Network identity. `system` is omitted — flake.nix mkHost defaults it to
  # aarch64-darwin (nix-darwin is Darwin-only; every host is Apple Silicon).
  hostName = "jevans-mbp";

  # Host class drives macOS system defaults (hosts/common/default.nix) and
  # nix-home's home-profile.preset (hosts/common/home.nix).
  class = "workstation";

  # The `primary` host backs the `default` darwinConfigurations alias and the
  # CI hmActivationPackage output. Exactly one host should set this.
  primary = true;

  # Serving width per role-map resident on this host. Inkling 2 Mini decodes
  # two requests at a time; Gemma 4 12B, the speech-to-text and the
  # text-to-speech residents decode four. nix-ai derives each worker's decode
  # flags, LiteLLM admission and request timeouts from these numbers.
  modelConcurrency = {
    inkling-2-mini = 2;
    gemma-4-12b = 4;
    qwen3-asr-1-7b = 4;
    ming-3-0-tts = 4;
  };

  # Local official MLX inference server sizing for the four static residents.
  # Weights: Inkling 2 Mini 17.31 GB (KV capped by the catalog's --max-kv-size),
  # Gemma 4 12B 6.74 GB plus the 6 GiB prompt-cache cap, Qwen3-ASR 2.46 GB and
  # Ming TTS 1.6 GB.
  mlx = {
    # Catalog selection, preload, per-model concurrency and the resident-worker
    # count derive from the role map (hosts/common/role-map.nix).

    cacheMemoryMb = 6144;
    prefillBatchSize = 2048;

    # MLX retained free-buffer pool. The host wired-memory ceiling is the
    # Metal guardrail; this limits reclaimable framework buffers below it.
    bufferCacheLimitGb = 8;

    # Per-worker L2 memory limit (every resident uses this value): four workers
    # at 15 GiB fit the 64 GiB wired ceiling less its 4 GiB baseline.
    memoryHardLimitGb = 15;

    # proxy.concurrencyLimit is deliberately NOT set here. nix-ai's module
    # already defaults it to 1 (modules/mlx/options-proxy.nix), so restating it
    # created a second independent literal that had to be kept in step with the
    # first by hand — exactly the drift the single-source rule exists to
    # prevent, and the shape that let mac-studio admit 4 while claiming 1.
    # This host wants the base value, so it says nothing and inherits it.

    # Clustered mode: this Mac is rank 0, coordinator, and HTTP endpoint. It
    # drives the Mac Studio worker over SSH when the Thunderbolt cable is in.
    clusterMode = {
      enable = true;
      role = "coordinator";
      peerSsh = "jevans@jevans-ms";
      quiesce = {
        apps = [
          "com.tinyspeck.slackmacgap"
          "com.apple.Safari"
          "com.apple.MobileSMS"
          "com.apple.iCal"
          "com.apple.reminders"
          "com.apple.podcasts"
          "com.apple.clock"
          "com.granola.app"
          "dev.kdrag0n.MacVirt"
          "com.microsoft.teams2"
        ];
        launchdLabels = [
          "com.microsoft.teams2.agent"
          "dev.dryvist.meeting-transcriber"
          "dev.litellm-local"
        ];
      };
      # Catalog-selected cluster model, identical on both ranks.
      # shardMemoryMb (the memory-headroom rank-start precondition) is set once
      # for both ranks in hosts/common/cluster-wired-limit.nix, from a measured
      # shard size. Change it there alongside this key.
      modelCatalogKey = "glm47-reap50";
    };
  };

  # Dedicated APFS volumes on the internal container (disk3). diskutil apfs list
  # to find the container. A bare name is logical separation only; an attrset
  # with `quota` adds a hard size ceiling (a maximum, not a reservation).
  apfsContainer = "disk3";
  apfsVolumes = [
    "HuggingFace"
    # Capped: holds a continuously-appended local data set bounded only by
    # time-based retention, which does not bound a burst. The ceiling keeps it
    # from consuming the container however those retention settings drift.
    {
      name = "Streams";
      quota = "100g";
    }
  ];
}
