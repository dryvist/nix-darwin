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

  # Local official MLX inference server sizing. The prompt cache stays at the
  # shared 8 GiB resilience cap.
  mlx = {
    # Every logical role resolves through the validated catalog entry; no
    # physical model id is repeated in deployed host configuration.
    catalog.qwen3-coder-30b = {
      class = "resident";
      roles = [
        "default"
        "quickest"
        "tool-calling"
        "coding"
        "large-context"
        "most-capable"
        "oss"
      ];
    };
    # Small always-loadable 9B (5.2 GB) for trivial local tasks via the
    # Gemini-CLI path and the hourly Obsidian summarizer pipe, which requests
    # this physical id directly. Swap-class with no roles compiles to a
    # llama-swap models.<id> entry keyed by the physical id, so it loads on
    # demand and routes without evicting the resident 30B.
    catalog.qwen35-9b-mlx.class = "swap";

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;

    # MLX retained free-buffer pool. The host wired-memory ceiling is the
    # Metal guardrail; this limits reclaimable framework buffers below it.
    bufferCacheLimitGb = 8;

    proxy.concurrencyLimit = 1;

    # Clustered mode: this Mac is rank 1 (worker) of the two-Mac JACCL cluster
    # when the Thunderbolt cable is in. The worker-side quiesce/restore hooks
    # (GUI quit + agent bootout allowlist sweep) are wired by
    # hosts/common/cluster-quiesce.nix. Standalone config above is untouched.
    clusterMode = {
      # Clustered ranks run under their own wired ceiling, applied by
      # clusterLinkPrep.clusterWiredLimitMb before any shard loads and
      # restored to the standalone value at link-down. The REAP-50 build
      # halves the per-rank shard. Background: Zammad AI/LLM Serving #17126.
      # Enabled together with the coordinator (lib/hosts/mac-studio.nix).
      enable = true;
      role = "worker";
      # Catalog-selected cluster model, identical on both ranks.
      modelCatalogKey = "glm47-reap50";
    };
  };

  # OrbStack container runtime. The ContainerData volume is created by
  # apfs-volumes (see apfsVolumes below); OrbStack only consumes it via the
  # home-manager Group Container symlink. enable = false omits the runtime +
  # symlink/env entirely.
  orbstack = {
    enable = true;
    containerVolume = "ContainerData";
  };

  # Dedicated APFS volumes on the internal container (disk3). Logical
  # separation only — no quota. diskutil apfs list to find the container.
  apfsContainer = "disk3";
  apfsVolumes = [
    "HuggingFace"
    "ContainerData"
  ];
}
