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

  # The default local model id is SHARED and pinned in
  # hosts/common/services-ai-stack.nix — this host deliberately sets no
  # per-host `defaultLocalModelId`. With no roleModelOverrides here, every role
  # (incl. the preloaded default) resolves to that shared id.

  # Local MLX inference server sizing (programs.mlx). Multi-turn agent clients
  # re-prefill 5-40K-token contexts; the 8192 MB default left no paged-cache
  # prefix reuse. Measured 2026-06-10: an identical-prefix re-request dropped
  # 21.8K -> 63 prefill tokens with these values.
  mlx = {
    cacheMemoryMb = 16384;
    prefillBatchSize = 2048;

    # Night cluster: this Mac is rank 1 (worker) of the two-Mac JACCL brain
    # when the Thunderbolt cable is in. The worker-side quiesce/restore hooks
    # (GUI quit + agent bootout allowlist sweep) are wired by
    # hosts/common/night-quiesce.nix. Day config above is untouched.
    nightCluster = {
      enable = true;
      role = "worker";
    };
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
