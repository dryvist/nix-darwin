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
    # 2026-06-09: switched from mlx-community/Qwen3.6-35B-A3B-mxfp4 — its hybrid
    # linear-attention architecture (qwen3_5_moe) crashes vllm-mlx whenever two
    # requests batch (mlx-lm conv_state shape bug; 402 crash-recovery events in
    # one log window, 0.1-4 tok/s effective). Qwen3-30B-A3B-Instruct-2507 is a
    # standard-attention MoE (qwen3_moe): benched 80-98 tok/s single-stream,
    # ~85 tok/s aggregate at 4-way concurrency, zero crashes, hermes tool
    # calling. See dryvist/nix-ai#915.
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

    # Two-resident serving pair (selected 2026-07-02; research JAC-155 —
    # weights measured from HF safetensors, archs verified against config.json,
    # cross-checked via codex + agy):
    #   default — gpt-oss-120b MXFP4-Q8: 63.3 GB, model_type gpt_oss (standard
    #     sliding+full softmax attention — NOT the qwen3_next/qwen3_5_moe
    #     linear-attention crash class from nix-ai#915), 117B total / 5.1B
    #     active (best TPS in its capability class), Apache-2.0. Tool calls
    #     need the harmony parser (vllm-mlx >= 0.4.0, nix-ai#1083).
    #   coding — Qwen3-Coder-30B-A3B 4-bit: 17.1 GB, qwen3_moe — the exact
    #     architecture of the previously-resident known-good 30B-A3B-2507.
    # Combined 80.4 GB weights against the 118 GB wired ceiling leaves ~37 GB
    # for paged-KV + framework. 8-bit coder (32.4 GB) is the tracked upgrade
    # if coding fidelity wins over KV headroom after benchmarks.
    defaultLocalModelId = "mlx-community/gpt-oss-120b-MXFP4-Q8";
    roleModelOverrides = {
      coding = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
    };

    # MLX sizing for TWO resident workers plus a swap tier. cacheMemoryMb
    # applies PER worker, so 2 x 6144 MB resident caches + 80.4 GB resident
    # weights ≈ 92.4 GB. That leaves room for one swap-tier Qwen3.6 model at a
    # time: 35B path = 92.4 + 20.4 + 3.0 ≈ 115.8 GB, 27B path = 92.4 + 16.1 +
    # 3.0 ≈ 111.5 GB. The 118 GB wired ceiling still has a small margin for the
    # proxy and framework while keeping the resident pair warm.
    #
    # NOTE the two swap models are different architectures: 35B is the A3B MoE
    # (3B active, ~113 tok/s measured); 27B is DENSE (no A3B variant exists on
    # mlx-community — the id originally registered here, Qwen3.6-27B-A3B-4bit,
    # was a phantom repo that 404'd on every load). Dense 27B decodes slower
    # but runs all weights per token; keep it only if quality beats 35B-A3B in
    # evals. Verify any new model id against huggingface BEFORE registering.
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
      preload = [
        "default"
        "coding"
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
        ];
        "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit" = [
          "--tool-call-parser"
          "qwen3_coder"
        ];
        # Qwen3.6 parser args live on their mlx.models entries below —
        # modelExtraArgs only reaches role-registry models (nix-ai
        # modules/mlx default.nix registryModels), so keys for ad-hoc
        # swap-tier models here are silently ignored.
      };
      # vllm-mlx 0.4.0's paged KV cache is incompatible with gpt-oss's
      # alternating sliding-window attention: generation fails with
      # "[broadcast_shapes] Shapes (1,8,64,64) and (1,8,115,64) cannot be
      # broadcast" (paged-cache block size vs. prompt length). Prefix caching
      # requires the paged cache, so both go off for this model only; the
      # Qwen coder keeps prefix caching, which its agentic workloads reuse.
      modelFlagOverrides = {
        "mlx-community/gpt-oss-120b-MXFP4-Q8" = {
          pagedKvCache = false;
          enablePrefixCaching = false;
        };
        # Global programs.mlx.maxRequestTokens (8192, see modules/mlx in nix-ai)
        # hard-caps every client-requested max_tokens on this host — good
        # general defense against a runaway generation, but too low for this
        # model's actual job: it is Hermes's agent brain (NousResearch
        # hermes-agent on LXC 517000), whose multi-turn tool-calling and
        # truncation-recovery paths legitimately need more than 8192 output
        # tokens per turn (a ~600-word explanation alone is close to that
        # ceiling). Raise only this model's ceiling back to vllm-mlx's own
        # 32768 server default; gpt-oss and any future model keep the tighter
        # 8192 safety net. 32768 (not higher) also matches hermes-agent's own
        # hardcoded retry-boost ceiling (NousResearch/hermes-agent
        # conversation_loop.py `max(32768, requested_cap)`), so a truncated
        # response's retry-boost lands exactly at the server's cap instead of
        # exceeding it.
        "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit" = {
          maxRequestTokens = 32768;
        };
        "mlx-community/Qwen3.6-35B-A3B-4bit" = {
          cacheMemoryMb = 3072;
          autoUnloadIdleSeconds = 900;
          maxNumSeqs = 2;
          maxRequestTokens = 32768;
        };
        "mlx-community/Qwen3.6-27B-4bit" = {
          cacheMemoryMb = 3072;
          autoUnloadIdleSeconds = 900;
          maxNumSeqs = 2;
          maxRequestTokens = 32768;
        };
      };
    };

    # Qwen3.6 lives in the non-resident swap tier. It is not preloaded at boot;
    # the router can load either model on demand, and the swap group unloads it
    # after it goes idle so it does not crowd out the resident pair.
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
        ];
      };
      "mlx-community/Qwen3.6-27B-4bit" = {
        ttl = 900;
        extraArgs = [
          "--tool-call-parser"
          "qwen3_coder"
          "--reasoning-parser"
          "qwen3"
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
