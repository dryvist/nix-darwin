# Per-host registry
#
# Pure static data only — NO `config`/`osConfig`/module references (that would
# create an eval-order dependency). Consumed by flake.nix `mkHost`, which threads
# each host's attrset to darwin modules via `specialArgs.hostConfig` and to
# home-manager modules via `extraSpecialArgs.hostConfig`.
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

    # OrbStack container runtime + dedicated external APFS data volume.
    # When enable = false the runtime + volume symlink/env are omitted entirely.
    orbstack = {
      enable = true;
      apfsContainer = "disk3"; # Find with: diskutil apfs list
      containerVolume = "ContainerData";
    };
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

    # MLX sizing for TWO resident workers — cacheMemoryMb applies PER worker,
    # so 2 x 12288 MB caches + 80.4 GB weights ≈ 105 GB, inside the 118 GB
    # wired ceiling with slack for the proxy/framework. Benchmark these on the
    # machine (JAC-115) before raising.
    mlx = {
      cacheMemoryMb = 12288;
      prefillBatchSize = 4096;
      # Keep both backends resident: no swap eviction, both preloaded at boot.
      proxy.groupSwap = false;
      preload = [
        "default"
        "coding"
      ];
      # Parsers differ per backend, so the global parser is off and each
      # physical model pins its own (harmony needs vllm-mlx >= 0.4.0).
      # --reasoning-parser is deliberately NOT set for gpt-oss yet: it has
      # historically conflicted with tool-call parsing in streaming mode —
      # re-evaluate during the benchmark pass.
      toolCallParser = null;
      modelExtraArgs = {
        "mlx-community/gpt-oss-120b-MXFP4-Q8" = [
          "--tool-call-parser"
          "harmony"
        ];
        "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit" = [
          "--tool-call-parser"
          "qwen3_coder"
        ];
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
      };
    };

    # OrbStack stays OFF until the real APFS container id is confirmed on the
    # machine (`diskutil apfs list`) during onboarding; flip to true then.
    orbstack.enable = false;
  };
}
