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
    # (qwen3_moe), benched 80-98 tok/s single / ~85 tok/s at 4-way concurrency
    # with hermes tool calling (dryvist/nix-ai#915). The old "qwen3_5_moe crashes
    # vllm-mlx on batching" rationale is retired — the 2026-07-08 agentic bench
    # ran that family under continuous batching at conc4 cleanly.
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

    # Resident brains (revised 2026-07-08 per the agentic tool-calling bench, HF
    # JacobPEvans/mlx-benchmarks; weights from HF safetensors):
    #   tool-calling — Qwen3.6-35B-A3B OptiQ-4bit: ~19.5 GB, qwen3_5_moe. Bench
    #     winner (100% valid tool calls, 0/20 multi-turn degradation at conc4 +
    #     thinking + large-ctx); the agent brain Hermes routes to by physical id.
    #     hermes tool parser + qwen3 reasoning, thinking on. glm47 and stock 8-bit
    #     degraded — left unregistered.
    #   coding — Qwen3-Coder-30B-A3B 4-bit: 17.1 GB, qwen3_moe (unchanged).
    # gpt-oss-120b MXFP4-Q8 (63.3 GB, default/oss aliases) is NO LONGER preloaded:
    # it failed the agentic gate (0%), so it drops to on-demand and idle-unloads
    # instead of holding 63 GB warm. Resident weights = 17.1 + 19.5 ≈ 36.6 GB.
    defaultLocalModelId = "mlx-community/gpt-oss-120b-MXFP4-Q8";
    roleModelOverrides = {
      tool-calling = "mlx-community/Qwen3.6-35B-A3B-OptiQ-4bit";
      coding = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
    };

    # MLX sizing: two resident brains (coder + OptiQ) plus on-demand swap.
    # cacheMemoryMb is PER worker — coder keeps the 6144 MB default, OptiQ is
    # raised to 16384 MB (below) for its 40-58K-token contexts. Resident budget ≈
    # 36.6 GB weights + 6 + 16 GB caches ≈ 58.6 GB, far under the ~109 GB
    # cache-clear trip (gpuMemoryUtilization 0.80 on 128 GB; never exceed 0.85).
    # An on-demand gpt-oss swap-in (63.3 GB + cache) transiently pushes past the
    # trip alongside the brains — pre-existing on a 128 GB box; it idle-unloads
    # back to the 58.6 GB baseline.
    mlx = {
      cacheMemoryMb = 6144;
      prefillBatchSize = 2048;
      # Keep both backends resident: no swap eviction, both preloaded at boot,
      # and no idle eviction anywhere — this host's entire job is holding
      # these weights, so the workstation rationale for aggressive TTLs
      # (idle-weight dwell starving the desktop working set) does not apply.
      # A TTL here would mean the first request after any quiet period pays
      # the ~60-120 s 120B cold start.
      proxy = {
        groupSwap = false;
        idleTtl = 0;
        # llama-swap hard-429s anything beyond concurrencyLimit (default 2),
        # while vllm-mlx itself batches 4 sequences (max-num-seqs) and queues
        # the rest gracefully. Measured on-host: a 4-way benchmark burst got
        # 98/100 requests rejected at the proxy before the workers saw them.
        # 8 = one full batch running + one queued at the worker; agents and
        # the web UI burst-tolerate instead of hard-failing.
        concurrencyLimit = 8;
      };
      autoUnloadIdleSeconds = 0;
      # Resident brains warmed at boot: coder (coding) + OptiQ (tool-calling).
      # gpt-oss (default) is deliberately omitted — see the composition note.
      preload = [
        "coding"
        "tool-calling"
      ];
      # Parsers differ per backend, so the global parser is off and each
      # physical model pins its own (harmony needs vllm-mlx >= 0.4.0).
      # --reasoning-parser WAS deliberately left unset for gpt-oss (comment
      # here previously cited a --reasoning-parser/--tool-call-parser
      # streaming conflict in vllm-mlx 0.2.6). Confirmed live 2026-07-06 that
      # leaving it unset is the actual root cause of harmony channel markers
      # ("analysis" ... "assistantfinal") leaking verbatim into
      # message.content in streaming mode (OpenWebUI's request path) — the
      # gpt-oss reasoning parser (added vllm-mlx 0.2.7 for exactly this
      # channel-token format) was never engaged, so nothing strips the
      # channel markers or routes analysis text to reasoning_content. Current
      # pin is vllm-mlx 0.4.0 (lib/versions.nix), well past the 0.2.6
      # conflict; --tool-call-parser harmony and --reasoning-parser gpt_oss
      # coexist fine there.
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
      # vllm-mlx 0.4.0's paged KV cache is incompatible with gpt-oss's
      # alternating sliding-window attention: generation fails with
      # "[broadcast_shapes] Shapes (1,8,64,64) and (1,8,115,64) cannot be
      # broadcast" (paged-cache block size vs. prompt length). Prefix caching
      # requires the paged cache, so both go off for this model only; the
      # Qwen coder keeps prefix caching, which its agentic workloads reuse.
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
      };
    };

    # Qwen3.6-35B lives in the non-resident swap tier. It is not preloaded at
    # boot; the router loads it on demand, and the swap group unloads it after
    # it goes idle so it does not crowd out the resident pair. (The dense 27B
    # was retired 2026-07-07 after evals: 4x slower than the 35B MoE with no
    # quality niche.)
    mlx.models = {
      # extraArgs must be set HERE, not in modelExtraArgs above: ad-hoc
      # models get their serve flags only from this attr. Without the
      # tool-call parser the global --enable-auto-tool-choice makes
      # vllm-mlx exit at argparse ("--enable-auto-tool-choice requires
      # --tool-call-parser"), so every swap-in 500'd with llama-swap's
      # "upstream command exited prematurely" (found 2026-07-07 eval).
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
