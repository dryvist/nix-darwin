# mac-studio — M4 Max / 128 GB headless network server for the homelab.
#
# Serving detail lives in nix-ai's validated model catalog
# (modules/mlx/catalog-data.nix): parser stacks, chat-template kwargs, and
# per-class flag profiles. This host only picks entries + classes and sets
# host-scoped runtime posture. Add or fix serve args in the catalog, not here.
{
  # Network identity. `system` omitted (mkHost defaults to aarch64-darwin).
  hostName = "jevans-ms";

  # Headless, always-on LAN inference/batch server. Drives server-class macOS
  # defaults (hosts/common/default.nix) and nix-home's server preset.
  class = "server";

  # The default local model id is SHARED and pinned in
  # hosts/common/services-ai-stack.nix (no per-host default). This host pins its
  # two warm brains via roleModelOverrides (2026-07-08 agentic tool-calling
  # bench; verdicts + capacity in HF JacobPEvans/mlx-benchmarks + apps
  # docs/BRAIN_ROTATION.md):
  #   tool-calling — stock Qwen3.6-35B-A3B-4bit: the live ai-default fleet
  #     brain (nix-ai#915) and the brain Hermes routes to. Replaces the
  #     OptiQ-4bit twin, whose vllm-mlx VLM-misdetect crashes it; revert to
  #     OptiQ once that engine bug is fixed.
  #   coding — Qwen3-Coder-30B-A3B 4-bit.
  # gpt-oss-120b (63.3 GB) stays in the catalog as swap-class (on-demand,
  # idle-unload, never preloaded); reach it by physical id or add a role
  # override if a role should target it.
  roleModelOverrides = {
    tool-calling = "mlx-community/Qwen3.6-35B-A3B-4bit";
    coding = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
  };

  mlx = {
    # Validated catalog selections (profiles in nix-ai catalog-data.nix).
    # Residents ≈ 58.6 GB with caches, far under the ~109 GB cache-clear trip
    # (gpuMemoryUtilization 0.80 on 128 GB); an on-demand gpt-oss swap-in
    # transiently exceeds the trip — pre-existing; it idle-unloads.
    catalog = {
      # Stock 35B is the resident fleet brain (ai-default, nix-ai#915). OptiQ
      # is demoted to swap: its vllm-mlx VLM-misdetect crashes it, so it must
      # not be a preloaded resident. Same ~19.4 GB weights either way, so the
      # resident footprint is unchanged.
      qwen36-35b.class = "resident";
      qwen3-coder-30b.class = "resident";
      qwen36-optiq.class = "swap";
      gpt-oss-120b.class = "swap";
      # LARGE daily-rotation brain (apps ai_default_model_large;
      # docs/BRAIN_ROTATION.md).
      qwen3-next-80b.class = "swap";
    };

    cacheMemoryMb = 6144;
    prefillBatchSize = 2048;
    # Server host: no group swap, no global idle eviction (per-class unloads
    # come from the catalog). A blanket TTL would make each resident brain pay
    # a 60-120 s cold start after any quiet period.
    proxy = {
      groupSwap = false;
      idleTtl = 0;
      # 8 (up from the default 2): llama-swap hard-429s beyond this while
      # vllm-mlx batches + queues gracefully — a 4-way burst measured 98/100
      # rejected at the proxy. 8 = one batch running + one queued.
      concurrencyLimit = 8;
    };
    autoUnloadIdleSeconds = 0;
    # Resident brains warmed at boot: coder (coding) + stock 35B (tool-calling,
    # the ai-default fleet brain). gpt-oss + OptiQ omitted — swap-class above.
    preload = [
      "coding"
      "tool-calling"
    ];
    # Global parser off; every backend's parser comes from its catalog entry.
    toolCallParser = null;

    # Clustered mode: this Mac is rank 0 (coordinator) of the two-Mac JACCL
    # brain when the Thunderbolt cable is in — it binds the cluster endpoint on
    # loopback :11440, gated by llm-gate (hosts/mac-studio/default.nix). The
    # link watcher quiesces normal serving at link-up and re-warms the preload
    # list on unplug.
    clusterMode = {
      # DISABLED 2026-07-12: boot-time auto-bring-up panicked both hosts
      # (WindowServer starvation under the shard's wired load). Re-enable
      # together with the worker once the wired-headroom mitigation lands.
      enable = false;
      role = "coordinator";
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
