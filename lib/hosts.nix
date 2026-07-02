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

    # Same model as the laptop for now. This 128 GB headless box has ample room
    # for a larger model (more accuracy) — revisit and benchmark on-machine.
    defaultLocalModelId = "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit";

    # MLX sizing — MAX from day one; inference is this box's sole purpose (not
    # "start small"). The 30B-A3B model is ~17 GB resident on 128 GB, so there is
    # large headroom. Benchmark these UPWARD on the machine.
    mlx = {
      cacheMemoryMb = 65536;
      prefillBatchSize = 4096;
    };

    # OrbStack stays OFF until the real APFS container id is confirmed on the
    # machine (`diskutil apfs list`) during onboarding; flip to true then.
    orbstack.enable = false;
  };
}
