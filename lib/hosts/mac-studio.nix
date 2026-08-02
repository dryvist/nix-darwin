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
    # 2026-07-27: promoted from the Coder-30B to the 35B for standalone
    # (MacBook unplugged, no cluster). Every candidate was measured on THIS
    # host against a dedicated isolated worker on a scratch port, with the
    # loaded checkpoint confirmed by lsof -i :PORT -> pid -> `ps -p <pid>`
    # reading --model. That step is mandatory, not ceremony: the alias map
    # above routes every other model's physical id onto the resident entry
    # and the server echoes the requested name back, so a model id in a
    # request or a response proves nothing about which weights answered.
    #
    # Headline metric is CUMULATIVE tok/s — (prompt + completion) / wall —
    # so prefill gains count. Identical 111-118 token prompt, 300 max_tokens,
    # 3 timed runs after a discarded warmup, decode-concurrency 1:
    #
    #   model                             cumulative  decode  ttft   tools
    #   Qwen3.6-35B-A3B-4bit                   115.2    84.9  0.12s  PASS
    #   Qwen3-Next-80B-A3B-Instruct-4bit        97.5    71.5  0.08s  PASS
    #   GLM-4.7-Flash-4bit                      95.8       -  -      FAIL
    #   gpt-oss-120b-MXFP4-Q8 (peer-measured)  51-54   40-43  0.23s  FAIL
    #
    # The 35B wins on throughput outright while being the smallest of the
    # four (19.4 GB), which also leaves headroom to raise concurrency later.
    # GLM-4.7-Flash is disqualified on tool calls, not speed: given two tools
    # it emits no call at all and stops on `length`. gpt-oss-120b is
    # disqualified because mlx-lm ships no harmony parser, so tool_calls is
    # null and raw <|channel|> markup leaks into content.
    singleModel = "mlx-community/Qwen3.6-35B-A3B-4bit";

    # Small always-loadable 9B for trivial local tasks (Gemini-CLI path).
    # singleModel would otherwise demote every non-resident to disabledModels;
    # this keeps the 9B servable as an on-demand swap tier beside the pinned
    # resident (nix-ai alwaysAvailableModels; never evicts the resident, no
    # alias onto its roles). ~5.2 GB on demand — ceilings unchanged.
    alwaysAvailableModels = [ "mlx-community/Qwen3.5-9B-MLX-4bit" ];

    # Validated catalog selections (profiles in nix-ai catalog-data.nix).
    # Every logical role resolves to the 35B — required so it's the only entry
    # the module's role-coverage assertion needs satisfied in single-model
    # mode. The Coder-30B, the 80B and the 27B judge are configured but carry
    # no roles (disable-not-delete): swap-class, kept in the tree, and — like
    # every other non-resident entry — demoted to disabledModels by
    # singleModel rather than deleted.
    catalog = {
      # 2026-07-27 standalone bench winner on cumulative throughput, and the
      # resident that every role resolves to. Thinking is off in its catalog
      # entry, which matters for Hermes: a thinking variant spends hundreds
      # of reasoning tokens before it emits a tool call, and Hermes pays that
      # latency on every single action it takes.
      qwen36-35b = {
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
      qwen36-27b-mxfp4.class = "swap";
      qwen35-9b-optiq.class = "swap";
      # Small always-loadable 9B (5.2 GB) for trivial local tasks via the
      # Gemini-CLI path — on-demand swap tier, idle-unloaded, never evicts a
      # resident. Addressable by its physical id (mlx-community/Qwen3.5-9B-MLX-4bit).
      qwen35-9b-mlx.class = "swap";
      qwen36-optiq.class = "swap";
      gpt-oss-120b.class = "swap";
      # Thinking sibling: the deep-analysis escalation tier, on demand.
      qwen3-next-80b.class = "swap";
    };

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;
    # NO per-model concurrency override: the resident inherits
    # proxy.concurrencyLimit below, so it is served at concurrency 1 — the
    # exact condition every benchmark above was run under.
    #
    # The 4x override this replaces was written for the Coder-30B and was
    # measured actively harmful on 2026-07-27. Admitting 4 concurrent streams
    # to one GPU gave 12.5 tok/s per stream, drove gate p90 to 194 s with a
    # 1298 s tail, returned 429 to 52% of requests over the preceding hour,
    # and ultimately wedged the worker outright (a router request failed with
    # 502 after a 40-minute hang). Concurrency buys nothing here to offset
    # that: mlx_lm.server serializes decode internally regardless, so 4-way
    # admission only time-slices one GPU and inflates every caller's latency.
    #
    # This is current operating guidance while single-stream stability is
    # being established, not a permanent ceiling — raising it is a one-line
    # change to serveConcurrency once concurrency-1 is proven solid.

    # Server host: no group swap, no global idle eviction (per-class unloads
    # come from the catalog). A blanket TTL would make each resident brain pay
    # a 60-120 s cold start after any quiet period.
    proxy = {
      groupSwap = false;
      idleTtl = 0;
      # Match the official mlx_lm prompt/decode workers: one request at a time.
      concurrencyLimit = serveConcurrency;
    };

    # Resident brain warmed at boot: the 35B, the only servable model.
    # "default" is one of several role aliases that all resolve to that same
    # entry in singleModel mode; the full list is qwen36-35b's `roles`
    # attribute above, which is also where goal-judge is declared. This used to
    # read `[ "goal-judge" ]` — also a valid alias to the SAME resident, so
    # functionally a no-op change — but that name reads as "warm a separate,
    # smaller judge model", which does not exist on this host: every role
    # here, including goal-judge, aliases the one 35B resident (ttl=0). That
    # misreading cost a real multi-hour misdiagnosis of a warmup starvation
    # incident on 2026-08-01 (the actual cause was external: something
    # kickstarting the warmup agent in a tight loop, force-reloading this
    # SAME resident over and over — see nix-ai's mlx-warmup.py RE-INVOCATION
    # BOUND). "default" says what actually happens here.
    preload = [ "default" ];

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
