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
    catalog = {
      qwen3-coder-30b = {
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
      qwen35-9b-mlx.class = "swap";
      # Qwen3.8-27B — current small/midsize generation, servable here on demand.
      #
      # Deliberately swap-class, NOT resident: promoting it would demote
      # qwen3-coder-30b, which is a ~3B-active MoE, in favour of a model that
      # activates all 27B. On this machine — a laptop that is also a cluster peer
      # under a shared memory cap — that trades the fast local coding path for an
      # unmeasured one. Swap-class keeps it addressable by its physical id
      # everywhere while the Studio carries the default-routing switch.
      #
      # To promote after the throughput numbers land: move the roles list from
      # qwen3-coder-30b to the qwen38-27b entry and flip the classes.
      qwen38-27b.class = "swap";
    };

    # Resident judge model, in its own llama-swap group (nix-ai
    # programs.mlx.judge, modules/mlx/options-judge.nix). Bypasses the
    # catalog/maxResidentWorkers topology entirely: persistent + non-exclusive
    # means it is never evicted by the main brain's exclusive group and never
    # evicts that group itself, so it answers even while the main brain is
    # busy serving a long request. Physical id is already cached under
    # HF_HOME (2.1 GB weights) — see hosts/common/residency-budget.nix for the
    # memoryHardLimitGb halving this needs.
    judge = {
      enable = true;
      model = "mlx-community/Qwen3-4B-Instruct-2507-4bit";
    };

    # persistent:true only protects the judge from eviction — it does NOT
    # preload it. The warmup LaunchAgent (native to nix-ai, mlx-warmup.py)
    # is the actual preload mechanism: it sends a real completion to every
    # role in this list right after llama-swap comes up, so the first REAL
    # request never pays the cold-load cost. "judge" listed BEFORE "default":
    # the list warms sequentially and the judge (2.1 GB, seconds to load)
    # must not sit queued behind the 30B's slower cold load.
    preload = [
      "judge"
      "default"
    ];

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;

    # Two workers can be resident at once now (the catalog brain plus the
    # judge above), so the single-worker budget hosts/common/residency-budget.nix
    # derives (kMax still 1 there — the judge sits outside maxResidentWorkers)
    # must be halved by hand: (100 GiB ceiling - 4 GiB baseline reserve) / 2
    # workers = 48 GiB, rounded down for cushion. Applies to every worker
    # equally (MLX_L1_MEMORY_LIMIT_BYTES is one shared wrapper-level export),
    # including the judge, whose real usage (~2-3 GiB) sits nowhere near it.
    memoryHardLimitGb = 46;

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
      # shardMemoryMb (the memory-headroom rank-start precondition) is set once
      # for both ranks in hosts/common/cluster-wired-limit.nix, from a measured
      # shard size. Change it there alongside this key.
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
