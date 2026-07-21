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

  # The default local model id is SHARED and pinned in
  # hosts/common/services-ai-stack.nix — this host deliberately sets no
  # per-host `defaultLocalModelId`. With no roleModelOverrides here, every role
  # (incl. the preloaded default) resolves to that shared id.

  # Local MLX inference server sizing (programs.mlx). Multi-turn agent clients
  # re-prefill 5-40K-token contexts; the 8192 MB default left no paged-cache
  # prefix reuse. Measured 2026-06-10: an identical-prefix re-request dropped
  # 21.8K -> 63 prefill tokens with these values.
  mlx = {
    cacheMemoryMb = 16384;
    prefillBatchSize = 2048;

    # Paired with appleSiliconTunables.wiredLimitMb = 100000 (104.86 GB ceiling)
    # in hosts/macbook-m4/default.nix — one decision, not two knobs. This is the
    # operational cap that matters: it sets the emergency KV-clear trip at
    # (util + 0.05) * 137.44 = 100.3 GB, below the 104.86 GB wired ceiling
    # (4.5 GB margin), so the worker sheds cache and stays fully wired before it
    # could ever spill to swap. Raising the ceiling without raising util does
    # nothing — the trip, not the ceiling, is what caps usable memory.
    # https://docs.jacobpevans.com/local-llm/memory-ceilings
    gpuMemoryUtilization = 0.68;

    # MLX retained free-buffer pool. Trimmed from the 12 GB module default to
    # keep the resident footprint under allocation_limit.
    bufferCacheLimitGb = 8;

    # Same batch-uniformity guard as the serving host: a repetition penalty is
    # a logits processor, and mlx_lm's batch generator dies on a batch mixing
    # requests that carry one with requests that do not (nix-ai#1234). This dev
    # sidecar sees ad-hoc callers with and without sampling params, which is the
    # same mix — set it here too rather than wait to be surprised.
    defaultRepetitionPenalty = 1.05;

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
      # Explicit cluster model, identical on both ranks — see the coordinator
      # block (lib/hosts/mac-studio.nix) for the sizing rationale.
      model = "mlx-community/GLM-4.7-REAP-50-mxfp4";
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
