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
  # model ids stay centralized in nix-ai's validated catalog.

  mlx = {
    # SINGLE-MODEL MODE (2026-07-23, supersedes the earlier
    # single-resident-brain-group posture): only the Coder-30B is servable.
    # Every alias — every logical role below AND every other catalog
    # model's own physical id — routes to it (programs.mlx.singleModel
    # aliases every other compiled model's id onto the resident entry).
    # Verified live: a request naming mlx-community/Qwen3.5-9B-OptiQ-4bit by
    # its own id was answered by the Coder-30B ("ROUTED").
    singleModel = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";

    # Validated catalog selections (profiles in nix-ai catalog-data.nix).
    # Every logical role resolves to the Coder-30B — required so it's the
    # only entry the module's role-coverage assertion needs satisfied in
    # single-model mode. The 80B fleet brain and the 27B judge are
    # configured but carry no roles (disable-not-delete): swap-class, kept
    # in the tree, and — like every other non-resident entry — demoted to
    # disabledModels by singleModel rather than deleted.
    catalog = {
      qwen3-coder-30b = {
        class = "resident";
        roles = [
          "default"
          "quickest"
          "tool-calling"
          "large-context"
          "most-capable"
          "oss"
          "coding"
          "goal-judge"
        ];
      };
      # Fleet brain (2026-07-17 agentic bench; >=75B mandate). Configured,
      # not deleted — no roles, so single-model mode routes everything to
      # the Coder-30B instead.
      qwen3-next-80b-instruct.class = "swap";
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
    # Resident model queues instead of instant-rejecting under overlap
    # (goal-mode judge calls got instant 429s when worker+compaction+judge
    # overlapped at the proxy default of 1 — mlx_lm.server serializes decode
    # internally, so a small proxy-side queue is safe). Verified live: 3
    # simultaneous requests all completed, no 429. Studio-only override —
    # the MacBook keeps concurrencyLimit=1 by design for its screenpipe 9B.
    modelConcurrencyLimits."mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit" = 4;
    # Server host: no group swap, no global idle eviction (per-class unloads
    # come from the catalog). A blanket TTL would make each resident brain pay
    # a 60-120 s cold start after any quiet period.
    proxy = {
      groupSwap = false;
      idleTtl = 0;
      # Match the official mlx_lm prompt/decode workers: one request at a time.
      concurrencyLimit = 1;
    };

    # Resident brain warmed at boot: the Coder-30B, the only servable model.
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
