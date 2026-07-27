# mac-studio — M4 Max / 128 GB headless network server for the homelab.
#
# Serving detail lives in nix-ai's validated model catalog
# (modules/mlx/catalog-data.nix): parser stacks, chat-template kwargs, and
# per-class flag profiles. This host only picks entries + classes and sets
# host-scoped runtime posture. Add or fix serve args in the catalog, not here.
let
  # THE per-model serving concurrency for this host. Everything concurrency-
  # shaped below derives from this one number — nothing restates it.
  #
  # It was previously restated: proxy.concurrencyLimit said 1 while a
  # modelConcurrencyLimits entry said a bare 4, so the host admitted 4 while its
  # single "source" claimed 1, and the two could drift silently. Since
  # 2026-07-27 the per-model override is gone entirely (the resident is a 40B+
  # single-slot model), so this is now the only concurrency number on the host.
  serveConcurrency = 1;
in
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
    # single-resident-brain-group posture): only one model is servable.
    # Every alias — every logical role below AND every other catalog
    # model's own physical id — routes to it (programs.mlx.singleModel
    # aliases every other compiled model's id onto the resident entry).
    # Verified live: a request naming mlx-community/Qwen3.5-9B-OptiQ-4bit by
    # its own id was answered by the resident entry ("ROUTED").
    #
    # 2026-07-27: promoted from the Coder-30B to the 80B fleet brain for
    # standalone (MacBook unplugged, no cluster). Measured on this host
    # against an isolated worker whose loaded weights were confirmed by
    # pid -> `ps` (the alias map above makes a request-echoed model name
    # worthless as evidence):
    #   Qwen3-Next-80B-A3B-Instruct-4bit  70.5 tok/s decode (70.0/70.6/70.9)
    #   Qwen3.6-35B-A3B-4bit              83.1 tok/s decode (82.6/83.2/83.5)
    # Both parse tool calls cleanly (single + parallel multi-tool, finish_reason
    # tool_calls, no markup leak). The 80B wins on capability at 1.8x the
    # >40 tok/s floor, and its mandated single-slot posture is what makes
    # that rate a SUSTAINED per-stream number rather than a quiet-box one:
    # the Coder-30B admitting 4 concurrent streams measured 12.5 tok/s per
    # stream and returned 429 to 52% of gate requests over the preceding hour.
    singleModel = "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit";

    # Small always-loadable 9B for trivial local tasks (Gemini-CLI path).
    # singleModel would otherwise demote every non-resident to disabledModels;
    # this keeps the 9B servable as an on-demand swap tier beside the pinned
    # resident (nix-ai alwaysAvailableModels; never evicts the resident, no
    # alias onto its roles). ~5.2 GB on demand — ceilings unchanged.
    alwaysAvailableModels = [ "mlx-community/Qwen3.5-9B-MLX-4bit" ];

    # Validated catalog selections (profiles in nix-ai catalog-data.nix).
    # Every logical role resolves to the 80B fleet brain — required so it's
    # the only entry the module's role-coverage assertion needs satisfied in
    # single-model mode. The Coder-30B and the 27B judge are configured but
    # carry no roles (disable-not-delete): swap-class, kept in the tree, and
    # — like every other non-resident entry — demoted to disabledModels by
    # singleModel rather than deleted.
    catalog = {
      # Fleet brain (2026-07-17 agentic bench; >=75B mandate), and since
      # 2026-07-27 the standalone resident that every role resolves to.
      qwen3-next-80b-instruct = {
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
      qwen3-coder-30b.class = "swap";
      qwen36-27b-mxfp4.class = "swap";
      qwen35-9b-optiq.class = "swap";
      # Small always-loadable 9B (5.2 GB) for trivial local tasks via the
      # Gemini-CLI path — on-demand swap tier, idle-unloaded, never evicts a
      # resident. Addressable by its physical id (mlx-community/Qwen3.5-9B-MLX-4bit).
      qwen35-9b-mlx.class = "swap";
      qwen36-35b.class = "swap";
      qwen36-optiq.class = "swap";
      gpt-oss-120b.class = "swap";
      # Thinking sibling: the deep-analysis escalation tier, on demand.
      qwen3-next-80b.class = "swap";
    };

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;
    # NO per-model concurrency override. The resident is now a 40B+ model, and
    # the 40B+ single-slot policy (nix-ai catalog-data.nix, user directive
    # 2026-07-21) forbids one: it must admit a single in-flight request at both
    # the proxy and the engine, so it inherits proxy.concurrencyLimit below.
    #
    # The 4x override this replaces was written for the Coder-30B and was
    # actively harmful by 2026-07-27: admitting 4 concurrent streams to one GPU
    # measured 12.5 tok/s per stream (vs 70.5 serialized on the 80B), drove gate
    # p90 to 194 s with a 1298 s tail, and still returned 429 to 52% of requests
    # in the preceding hour. Serializing trades nothing real — mlx_lm.server
    # serializes decode internally anyway — and converts instant rejection into
    # a bounded queue.

    # Server host: no group swap, no global idle eviction (per-class unloads
    # come from the catalog). A blanket TTL would make each resident brain pay
    # a 60-120 s cold start after any quiet period.
    proxy = {
      groupSwap = false;
      idleTtl = 0;
      # Match the official mlx_lm prompt/decode workers: one request at a time.
      concurrencyLimit = serveConcurrency;
    };

    # Resident brain warmed at boot: the 80B, the only servable model. The
    # role name is unchanged because every role now resolves to that entry.
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
