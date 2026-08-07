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

    # proxy.concurrencyLimit is deliberately NOT set here. nix-ai's module
    # already defaults it to 1 (modules/mlx/options-proxy.nix), so restating it
    # created a second independent literal that had to be kept in step with the
    # first by hand — exactly the drift the single-source rule exists to
    # prevent, and the shape that let mac-studio admit 4 while claiming 1.
    # This host wants the base value, so it says nothing and inherits it.

    # Clustered mode: this Mac is rank 1 (worker) of the two-Mac JACCL cluster
    # when the Thunderbolt cable is in. The worker-side quiesce/restore hooks
    # (GUI quit + agent bootout allowlist sweep) are wired by
    # hosts/common/cluster-quiesce.nix. Standalone config above is untouched.
    clusterMode = {
      # Clustered ranks run under their own wired ceiling, applied by
      # clusterLinkPrep.clusterWiredLimitMb before any shard loads and
      # restored to the standalone value at link-down. The REAP-50 build
      # halves the per-rank shard. Background: Zammad AI/LLM Serving #17126.
      # RE-ENABLED 2026-08-07 together with the coordinator
      # (lib/hosts/mac-studio.nix), which carries the full root-cause
      # rationale for the 2026-08-05 disable and this re-enable. The pair is
      # enabled and disabled as a unit — a half-enabled pair reads as
      # "clustered" while no cluster can ever form.
      enable = true;
      role = "worker";
      # Catalog-selected cluster model, identical on both ranks.
      modelCatalogKey = "glm47-reap50";
      # Arms the memory-headroom rank-start precondition (0 = off): the
      # glm47-reap50 per-rank shard is ~49 GB; 55000 leaves KV margin. Change
      # alongside modelCatalogKey if the selected cluster model changes.
      shardMemoryMb = 55000;
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

  # Dedicated APFS volumes on the internal container (disk3). diskutil apfs list
  # to find the container. A bare name is logical separation only; an attrset
  # with `quota` adds a hard size ceiling (a maximum, not a reservation).
  apfsContainer = "disk3";
  apfsVolumes = [
    "HuggingFace"
    "ContainerData"
    # Capped: holds a continuously-appended local data set bounded only by
    # time-based retention, which does not bound a burst. The ceiling keeps it
    # from consuming the container however those retention settings drift.
    {
      name = "Streams";
      quota = "100g";
    }
  ];
}
