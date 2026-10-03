# mac-studio — M4 Max / 128 GB headless network server for the homelab.
#
# Serving detail lives in nix-ai's validated model catalog
# (modules/mlx/catalog-data.nix): parser stacks, chat-template kwargs, and
# per-class flag profiles. The role map picks entries + classes; this host sets
# host-scoped runtime posture. Add or fix serve args in the catalog, not here.
let
  # THE proxy admission ceiling for this host. Per-model concurrency comes
  # from the role map (modelConcurrencyLimits); this is the upper bound the
  # proxy advertises.
  #
  # The canonical source is dryvist/tofu-proxmox's
  # modules/proxmox-stack/constants.tf (pipeline_constants.serving.
  # llm_concurrency); ansible-proxmox-ai derives its
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
  # Logical roles, catalog selection and per-model concurrency come from the
  # role map by host class (hosts/common/role-map.nix).

  mlx = {
    # Catalog selection, preload, per-model concurrency and the resident-worker
    # count derive from the role map (hosts/common/role-map.nix); the host adds
    # only runtime posture. The OCR model unloads after 600 s idle.
    catalog.unlimited-ocr.tweaks.ttl = 600;

    cacheMemoryMb = 8192;
    prefillBatchSize = 2048;

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
