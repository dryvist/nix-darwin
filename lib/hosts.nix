# Per-host registry
#
# Pure static data only — NO `config`/`osConfig`/module references (that would
# create an eval-order dependency). Consumed by flake.nix `mkHost`, which
# normalizes `class` (default "workstation") and derives `isServer`, then
# threads each host's attrset to darwin modules via `specialArgs.hostConfig`
# and to home-manager modules via `extraSpecialArgs.hostConfig`.
#
# Keyed by descriptive machine label (also the folder name under hosts/). The
# darwin configuration is exposed under `hostName` (see flake.nix) so
# `darwin-rebuild switch --flake .` host auto-detection resolves it.
#
# Fields are added here as consumers are wired up (PR-by-PR): a field lives in
# the registry only once a module or host file actually reads it, to avoid data
# that duplicates a host file without being consumed.
{
  macbook-m4 = {
    # Network identity. `system` is omitted — flake.nix mkHost defaults it to
    # aarch64-darwin (nix-darwin is Darwin-only; every host is Apple Silicon).
    hostName = "jevans-mbp";

    # Host class drives macOS system defaults (hosts/common/default.nix) and
    # nix-home's home-profile.preset (hosts/common/home.nix).
    class = "workstation";

    # The `primary` host backs the `default` darwinConfigurations alias and the
    # CI hmActivationPackage output. Exactly one host should set this.
    primary = true;

    # Local MLX physical model id, consumed at Nix eval time by
    # services.aiStack.defaultLocalModelId (hosts/*/services-ai-stack.nix, shared).
    # Non-secret public Hugging Face name; committed so evaluation stays pure (no
    # --impure, no keychain/env/file sourcing). Change via a reviewed commit.
    # 2026-06-09: Qwen3-30B-A3B-Instruct-2507, a standard-attention MoE
    # (qwen3_moe), ~85 tok/s at 4-way concurrency, hermes tool calling
    # (dryvist/nix-ai#915). The retired "qwen3_5_moe batching crash" claim was
    # disproven by the 2026-07-08 agentic bench (HF JacobPEvans/mlx-benchmarks).
    defaultLocalModelId = "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit";

    # Local MLX inference server sizing (programs.mlx). Multi-turn agent clients
    # re-prefill 5-40K-token contexts; the 8192 MB default left no paged-cache
    # prefix reuse. Measured 2026-06-10: an identical-prefix re-request dropped
    # 21.8K -> 63 prefill tokens with these values.
    mlx = {
      cacheMemoryMb = 16384;
      prefillBatchSize = 2048;
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
  };

  mac-studio = {
    # Network identity. `system` omitted (mkHost defaults to aarch64-darwin).
    hostName = "jevans-ms";

    # Headless, always-on LAN inference/batch server. Drives server-class macOS
    # defaults (hosts/common/default.nix) and nix-home's server preset.
    class = "server";

    # Resident brains (2026-07-08 agentic tool-calling bench; verdicts + capacity
    # in HF JacobPEvans/mlx-benchmarks + apps docs/BRAIN_ROTATION.md):
    #   tool-calling — Qwen3.6-35B-A3B OptiQ-4bit (~19.5 GB, qwen3_5_moe): bench
    #     winner, the brain Hermes routes to by physical id. glm47 + stock 8-bit
    #     degraded, left unregistered.
    #   coding — Qwen3-Coder-30B-A3B 4-bit (17.1 GB, qwen3_moe).
    # gpt-oss-120b (63.3 GB, default/oss) is NOT preloaded — 0% on the agentic
    # gate, so on-demand + idle-unload. Resident weights ≈ 36.6 GB.
    defaultLocalModelId = "mlx-community/gpt-oss-120b-MXFP4-Q8";
    roleModelOverrides = {
      tool-calling = "mlx-community/Qwen3.6-35B-A3B-OptiQ-4bit";
      coding = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
    };

    # MLX sizing (per-worker cacheMemoryMb; derivations in mlx-benchmarks
    # docs/RUNBOOK.md): residents ≈ 58.6 GB (coder + OptiQ weights + 6 + 16 GB
    # caches), far under the ~109 GB cache-clear trip (gpuMemoryUtilization 0.80
    # on 128 GB, never > 0.85). An on-demand gpt-oss swap-in transiently exceeds
    # the trip — pre-existing; it idle-unloads back to baseline.
    mlx = {
      cacheMemoryMb = 6144;
      prefillBatchSize = 2048;
      # Server host: no group swap, no global idle eviction (per-model unloads
      # are set below). A blanket TTL would make each resident brain pay a
      # 60-120 s cold start after any quiet period.
      proxy = {
        groupSwap = false;
        idleTtl = 0;
        # 8 (up from the default 2): llama-swap hard-429s beyond this while
        # vllm-mlx batches + queues gracefully — a 4-way burst measured 98/100
        # rejected at the proxy. 8 = one batch running + one queued.
        concurrencyLimit = 8;
      };
      autoUnloadIdleSeconds = 0;
      # Resident brains warmed at boot: coder (coding) + OptiQ (tool-calling).
      # gpt-oss (default) is deliberately omitted — see the composition note.
      preload = [
        "coding"
        "tool-calling"
      ];
      # Global parser off; each backend pins its own below (harmony needs
      # vllm-mlx >= 0.4.0). gpt-oss MUST set --reasoning-parser gpt_oss — unset,
      # its harmony channel markers ("analysis"/"assistantfinal") leak into
      # streamed message.content (root-caused 2026-07-06; nix-ai#1083).
      toolCallParser = null;
      modelExtraArgs = {
        "mlx-community/gpt-oss-120b-MXFP4-Q8" = [
          "--tool-call-parser"
          "harmony"
          "--reasoning-parser"
          "gpt_oss"
          # Server defaults keep request-level chat_template_kwargs overrideable.
          "--default-chat-template-kwargs"
          (builtins.toJSON {
            reasoning_effort = "low";
          })
        ];
        "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit" = [
          "--tool-call-parser"
          "qwen3_coder"
          "--timeout"
          "3600"
        ];
        # tool-calling role (resident agent brain). hermes parser for the general
        # Qwen3.6 XML tool format (qwen3_coder mis-parses it → empty function.name
        # repair storms); qwen3 reasoning, thinking ON (bench winner). --timeout
        # 3600 (on both residents) lifts the 300s disconnect_guard; keeps the
        # guard chain strict: server 3600 > router 2400 > client 1800.
        "mlx-community/Qwen3.6-35B-A3B-OptiQ-4bit" = [
          "--tool-call-parser"
          "hermes"
          "--reasoning-parser"
          "qwen3"
          "--default-chat-template-kwargs"
          (builtins.toJSON {
            enable_thinking = true;
          })
          "--timeout"
          "3600"
        ];
        # Swap-tier (mlx.models) args go on those entries below; keys here
        # only reach role-registry models and are otherwise silently ignored.
      };
      # gpt-oss needs pagedKvCache + prefix caching OFF: its sliding-window
      # attention hits a [broadcast_shapes] failure with vllm-mlx 0.4.0's paged
      # cache. The Qwen models keep prefix caching for agentic reuse.
      modelFlagOverrides = {
        # gpt-oss: demoted from preload. The global autoUnloadIdleSeconds = 0
        # would pin it resident-forever once loaded on demand, so re-arm a 15-min
        # idle unload to free its 63 GB back to the two-brain baseline.
        "mlx-community/gpt-oss-120b-MXFP4-Q8" = {
          pagedKvCache = false;
          enablePrefixCaching = false;
          autoUnloadIdleSeconds = 900;
        };
        # coding: resident, unchanged. The global maxRequestTokens (8192, modules/
        # mlx in nix-ai) is too low for agentic multi-turn, so keep 32768.
        "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit" = {
          maxRequestTokens = 32768;
        };
        # tool-calling (resident brain): HIGH KV budget for 40-58K-token contexts;
        # maxNumSeqs 8 = one continuous batch. The 65536 ceiling replaces the 32768
        # cap that fed the truncation/retry death-loop.
        "mlx-community/Qwen3.6-35B-A3B-OptiQ-4bit" = {
          cacheMemoryMb = 16384;
          maxNumSeqs = 8;
          maxRequestTokens = 65536;
        };
        "mlx-community/Qwen3.6-35B-A3B-4bit" = {
          cacheMemoryMb = 3072;
          autoUnloadIdleSeconds = 900;
          maxNumSeqs = 2;
          maxRequestTokens = 32768;
        };
        # Qwen3-Next-80B swap brain (mlx.models entry below). Small 4096 MB cache
        # keeps the on-demand swap-in under the ~109 GB trip (≈104.6 GB with
        # residents; derivation in mlx-benchmarks docs/RUNBOOK.md); idle-unload
        # frees it. prefixCaching off — unsupported for the qwen3_next
        # hybrid-attention family (mlx-benchmarks model-notes).
        "mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit" = {
          cacheMemoryMb = 4096;
          autoUnloadIdleSeconds = 900;
          maxNumSeqs = 2;
          maxRequestTokens = 32768;
          enablePrefixCaching = false;
        };
      };
    };

    # Non-resident swap tier: router loads on demand, idle-unloads so it never
    # crowds the resident pair. (Dense 27B retired 2026-07-07: 4x slower.)
    mlx.models = {
      # Swap-tier serve flags go on extraArgs HERE (modelExtraArgs only reaches
      # role-registry models). The tool-call parser is required — the global
      # --enable-auto-tool-choice makes vllm-mlx exit at argparse without it.
      "mlx-community/Qwen3.6-35B-A3B-4bit" = {
        ttl = 900;
        extraArgs = [
          "--tool-call-parser"
          "qwen3_coder"
          "--reasoning-parser"
          "qwen3"
          # Thinking off by default (requests can opt back in). extraArgs are
          # raw-concatenated + shell-parsed, so the JSON quotes itself (#1557).
          "--default-chat-template-kwargs"
          "'{\"enable_thinking\":false}'"
        ];
      };
      # Qwen3-Next-80B-A3B Thinking 4-bit — the LARGE daily-rotation brain (apps
      # ai_default_model_large; rotation + capacity in apps docs/BRAIN_ROTATION.md
      # and mlx-benchmarks docs/RUNBOOK.md). No enable_thinking kwarg: the
      # dedicated Thinking variant is always-on (no chat-template switch). hermes
      # tool parser + qwen3 reasoning; --timeout 3600 per the guard chain above.
      "mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit" = {
        ttl = 900;
        extraArgs = [
          "--tool-call-parser"
          "hermes"
          "--reasoning-parser"
          "qwen3"
          "--timeout"
          "3600"
        ];
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
  };
}
