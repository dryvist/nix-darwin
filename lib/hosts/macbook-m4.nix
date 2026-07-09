# macbook-m4 — M4 Max / 128 GB workstation (self-serving: localhost
# clients only, keeps load off the network server).
{
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
}
