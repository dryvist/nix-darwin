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
# Fields are added here as consumers are wired up (PR-by-PR): `class`,
# `otelHostName`, `mlx`, `wiredLimitMb`, and `orbstack` land with the PRs that
# consume them, to avoid data that duplicates a host file without being read.
{
  macbook-m4 = {
    # Network identity
    hostName = "jevans-mbp";
    system = "aarch64-darwin";

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

    # LAN DNS resolver(s) + search domain (match the host resolver). Non-secret.
    lanDnsServers = [ "10.0.1.1" ];
    lanSearchDomain = "jacobpevans.com";
  };
}
