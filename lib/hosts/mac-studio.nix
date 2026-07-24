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

  # Logical roles are assigned through catalog selections below. Physical
  # model ids stay centralized in nix-ai's validated catalog. Only one
  # resident brain at a time (single-resident-brain doctrine, 2026-07-23).

  mlx = {
    # Validated catalog selections (profiles in nix-ai catalog-data.nix).
    # Single-resident-brain doctrine (2026-07-23): only the Coder-30B stays
    # resident. The 80B fleet brain and the 27B judge are configured but
    # swap-class (disable-not-delete) — 3 resident models (~75GB weights +
    # 12GB buffer cache each) starved prefill headroom and violated the
    # locked one-resident-brain rule.
    catalog = {
      # Qwen3-Next-80B Instruct is the fleet brain (2026-07-17 agentic bench;
      # >=75B mandate) and doubles as the >=64K compression model. All fleet
      # roles resolve through this catalog selection. Swap-class: loads
      # on-demand rather than staying resident beside the Coder-30B.
      qwen3-next-80b-instruct = {
        class = "swap";
        roles = [
          "default"
          "quickest"
          "tool-calling"
          "large-context"
          "most-capable"
          "oss"
        ];
      };
      # Sole resident brain. Also serves as goal-judge: on a single-slot
      # Studio, a judge on a different model forces a load-swap every
      # goal-mode turn, so judge and worker share one model (verified
      # "JUDGE OK" live with zero model swap, 2026-07-23).
      qwen3-coder-30b = {
        class = "resident";
        roles = [
          "coding"
          "goal-judge"
        ];
      };
      # Swap-class, not deleted: still fully configured, just no longer
      # the goal-judge or resident.
      qwen36-27b-mxfp4.class = "swap";
      qwen35-9b-optiq.class = "swap";
      qwen36-35b.class = "swap";
      qwen36-optiq.class = "swap";
      gpt-oss-120b.class = "swap";
      # Thinking sibling: the deep-analysis escalation tier, on demand.
      qwen3-next-80b.class = "swap";
    };

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;
    # Server host: no group swap, no global idle eviction (per-class unloads
    # come from the catalog). A blanket TTL would make each resident brain pay
    # a 60-120 s cold start after any quiet period.
    proxy = {
      groupSwap = false;
      idleTtl = 0;
      # Match the official mlx_lm prompt/decode workers: one request at a time.
      concurrencyLimit = 1;
    };

    # Resident brain warmed at boot: the Coder-30B (doubles as goal-judge).
    # "tool-calling" dropped — it now resolves to the swap-class 80B, and
    # preloading a swap model at boot would defeat the single-resident intent.
    preload = [ "goal-judge" ];

    # Clustered mode: this Mac is rank 0 (coordinator) of the two-Mac JACCL
    # brain when the Thunderbolt cable is in — it binds the cluster endpoint on
    # loopback :11440, gated by llm-gate (hosts/mac-studio/default.nix). The
    # link watcher quiesces normal serving at link-up and re-warms the preload
    # list on unplug.
    clusterMode = {
      # RE-ENABLED 2026-07-18 in the supervised session the 2026-07-12
      # disable note called for (boot-time auto-bring-up had panicked both
      # hosts via WindowServer starvation; the link-state wired ceiling —
      # clusterLinkPrep.clusterWiredLimitMb — now bounds the shard's wired
      # load). Enabled together with the worker (lib/hosts/macbook-m4.nix).
      enable = true;
      role = "coordinator";
      # Catalog-selected cluster model, identical on both ranks. The expert-pruned
      # REAP-50 build (~98 GB, glm4_moe) halves the per-rank shard to ~49 GB
      # so it fits under the cluster wired ceiling with real KV headroom; the
      # full 198 GB GLM-4.7-4bit (module default) is reserved for supervised
      # sessions until the ceiling values are validated.
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
