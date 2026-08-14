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
  # 2026-07-27 the per-model override is gone entirely, so this is now the
  # only concurrency number on the host.
  #
  # It is ALSO no longer this repo's only definition of the number, just the
  # only one nix can evaluate hermetically. dryvist/tofu-proxmox's
  # modules/proxmox-stack/constants.tf (pipeline_constants.serving.
  # llm_concurrency) is the canonical source; ansible-proxmox-ai derives its
  # ai_llm_concurrency from it directly over the tofu_data.constants channel.
  # Flake evaluation has no network access, so this repo cannot derive the
  # same way — instead CI (.github/workflows/_llm-concurrency-parity.yml)
  # fetches dryvist/tofu-proxmox's published constant and fails the build
  # when it disagrees with the value below. Raise both together; the check
  # enforces that now, not this comment.
  serveConcurrency = 2;
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
    # 2026-08-14: switched to Qwen3.8-27B-4bit by operator decision — adopt the
    # newest generation now, revert only on measured evidence.
    #
    # THIS OVERRIDES AN EXISTING BENCHMARK VERDICT, deliberately. The previous
    # pin, mlx-community/Qwen3.6-35B-A3B-4bit, won the 2026-07-27 standalone
    # bench on cumulative tok/s (115.2, smallest of four candidates at 19.4 GB;
    # method and results table in ./mac-studio.md). That model is a 35B MoE with
    # ~3B active parameters per token; Qwen3.8-27B activates all 27B, offset by
    # hybrid attention (48 of 64 layers linear). Net throughput is therefore
    # UNMEASURED on this host and could regress.
    #
    # The throughput suite runs first in the mlx-benchmarks sweep specifically
    # to produce that number. If it regresses materially, revert is this one
    # line plus the AI_MODEL_LOCAL_LLM Doppler variable.
    singleModel = "mlx-community/Qwen3.8-27B-4bit";

    # Small always-loadable 9B (~5.2 GB) for trivial local tasks (Gemini-CLI
    # path). singleModel would otherwise demote every non-resident to
    # disabledModels; this keeps it servable as a swap tier (nix-ai
    # alwaysAvailableModels; no alias onto its roles).
    #
    # It no longer evicts the resident: that was the k_max = 1 collapsed-group
    # behaviour, corrected below. See ./mac-studio.md "Residency budget".
    alwaysAvailableModels = [ "mlx-community/Qwen3.5-9B-MLX-4bit" ];

    # RESIDENCY BUDGET — these two move together or the host over-commits.
    #
    #   maxResidentWorkers * memoryHardLimitGb <= wired ceiling (100 GiB here,
    #   from appleSiliconTunables.maxLocalLlmGb in hosts/mac-studio/default.nix)
    #
    # 2 x 48 = 96 GiB. The cushion is NOT the 4 GiB that subtraction suggests:
    # the non-MLX wired baseline measures ~3.4 GiB while a worker decodes, so
    # the strict worst case is 99.4 against 100 — roughly 0.6 GiB. It holds, and
    # overshoot spills to pageable memory rather than failing (the limit is a
    # shed-hint, not a refusal), but do not spend that 4 GiB.
    #
    # At the previous k_max = 1 the resident and the 9B shared one exclusive
    # group, so loading the 9B evicted the 35B and the next request paid a
    # reload — measured 2026-08-05. k_max = 2 restores the tiered topology so a
    # small-model load sits BESIDE the resident. It does not pin the 9B
    # resident: that entry keeps ttl 900 and still idle-unloads.
    #
    # k_max is the ONLY number stated here. memoryHardLimitGb is DERIVED from
    # the host ceiling in hosts/common/residency-budget.nix as
    # (maxLocalLlmGb - baselineReserve) / maxResidentWorkers, which at 100 GiB
    # and k=2 gives 48 GiB per worker. Change k_max alone and the per-worker
    # budget re-derives; nobody redoes the arithmetic, and an explicit override
    # is still held to the invariant by that module's assertion.
    #
    # suppressWiredLimit defaults true, so weights are pageable and overshoot
    # spills to swap rather than panicking. Rationale and the measurements
    # behind the reserve: ./mac-studio.md.
    maxResidentWorkers = 2;

    # Validated catalog selections (profiles in nix-ai catalog-data.nix).
    # Every logical role resolves to the 35B — required so it's the only entry
    # the module's role-coverage assertion needs satisfied in single-model
    # mode. The Coder-30B, the 80B and the 27B judge are configured but carry
    # no roles (disable-not-delete): swap-class, kept in the tree, and — like
    # every other non-resident entry — demoted to disabledModels by
    # singleModel rather than deleted.
    catalog = {
      # Current-generation resident that every role resolves to; must stay in
      # step with singleModel above (the role-coverage assertion enforces it).
      # Thinking is off in its catalog entry, which matters for Hermes: a
      # thinking variant spends hundreds of reasoning tokens before it emits a
      # tool call, and Hermes pays that latency on every single action it takes.
      qwen38-27b = {
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
      qwen3-next-80b-instruct.class = "swap";
      qwen3-coder-30b.class = "swap";
      # Previous resident and 2026-07-27 throughput winner (115.2 tok/s
      # cumulative). Kept swap-class as the revert target: if the Qwen3.8
      # throughput measurement regresses, restore its roles here and repoint
      # singleModel back at it.
      qwen36-35b.class = "swap";
      qwen35-9b-optiq.class = "swap";
      # Small always-loadable 9B (5.2 GB) for trivial local tasks via the
      # Gemini-CLI path — on-demand swap tier, idle-unloaded. Addressable by its
      # physical id (mlx-community/Qwen3.5-9B-MLX-4bit). It DOES evict the
      # resident at k_max = 1 — see the alwaysAvailableModels note above.
      qwen35-9b-mlx.class = "swap";
      qwen36-optiq.class = "swap";
      gpt-oss-120b.class = "swap";
      # Thinking sibling: the deep-analysis escalation tier, on demand.
      qwen3-next-80b.class = "swap";
    };

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;
    # NO per-model concurrency override: the resident inherits
    # proxy.concurrencyLimit below — 2 since 2026-08-06 (the 2026-07 benches
    # ran at 1). The 9B and every 40B+ entry keep their catalog
    # concurrencyLimit=1 pins, so only the resident serves 2. Why 2 is safe
    # where the 2026-07-27 4x override was harmful: ./mac-studio.md
    # "Serving concurrency".

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

    # Resident brain warmed at boot. Every role alias resolves to the same 35B
    # in singleModel mode, so this name is cosmetic — but it must not name a
    # role that reads as a separate model. It used to say `[ "goal-judge" ]`,
    # which cost a multi-hour misdiagnosis on 2026-08-01; see ./mac-studio.md
    # "Preload". "default" says what actually happens here.
    preload = [ "default" ];

    # Clustered mode: this Mac is rank 0 (coordinator) of the two-Mac JACCL
    # brain when the Thunderbolt cable is in — it binds the cluster endpoint on
    # loopback :11440, gated by llm-gate (hosts/mac-studio/default.nix). The
    # link watcher quiesces normal serving at link-up and re-warms the preload
    # list on unplug.
    clusterMode = {
      # Clustering is the operating goal for this pair: one TB5 cable turns
      # both Macs into a single inference cluster neither can match alone.
      # RE-ENABLED 2026-08-07 after closing every root cause the 2026-08-05
      # disable found:
      #
      #   - Standdown tight-loop (560 pair-wide standdowns, 1686
      #     rendezvous-absent strikes since 2026-07-12): fixed. nix-ai writes a
      #     halt marker on peer-absent standdown so the warmup-agent reload
      #     loop cannot recur unbounded.
      #   - PD-debt exhaustion: fixed — nix-ai#1478 (merged, self-reboot);
      #     preflight check implemented in nix-ai PR #1556 (tracking #1442).
      #   - Warmup-slot starvation: fixed via repair-attempt caps in nix-ai's
      #     cluster resilience module.
      #   - bridge0 re-enslaving the Thunderbolt ports on reboot: fix in
      #     flight, dryvist/nix-darwin#1768 / PR #2073. Until it lands, a
      #     reboot on either rank needs a manual un-enslave of the TB ports
      #     before the link can come back up.
      #   - TCC store-path grants for the cluster interpreter and signing
      #     identity: fixed (hosts/common/mlx-cluster-signing.nix,
      #     appleInterpreter in hosts/common/home.nix).
      #
      # Invariant: this pair is enabled and disabled as a unit. A half-enabled
      # pair reads as "clustered" while no cluster can ever form — see the
      # matching block in lib/hosts/macbook-m4.nix. Re-enabling requires cable
      # physically in, both ranks up on the same generation, and a supervised
      # session — the same bar the 2026-07-12 disable note set and every prior
      # re-enable met.
      enable = true;
      role = "coordinator";
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
