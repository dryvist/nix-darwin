# Cluster wired-ceiling wiring (split out for the per-file byte cap).
#
# The clustered wired ceilings and their standalone-restore counterparts live
# ONCE in nix-darwin's system.clusterLinkPrep (clusterWiredLimitMb + the
# computed, read-only standaloneWiredLimitMb), which also emits the exact-value
# sudoers grants. This module feeds those SAME values into nix-ai's
# programs.mlx.clusterMode so the link watcher and cluster-join/cluster-detach
# commands actually receive CLUSTER_WIRED_LIMIT_MB and
# CLUSTER_STANDALONE_WIRED_LIMIT_MB in their environment.
#
# Without this bridge the pin is a no-op — the sudoers grants exist with
# nothing configured to invoke them (INC-17076, INC-17062).
#
# Both ranks need the ceiling, so this is NOT gated on role like
# cluster-quiesce.nix. Deriving from osConfig (never re-declaring the numbers)
# makes drift between the sudoers grant and the watcher restore impossible.
{
  lib,
  osConfig,
  hostConfig,
  ...
}:
let
  # Attribute-existence gate (repo convention): non-inference hosts have no
  # `mlx` at all, and a host may declare `mlx` without `clusterMode`.
  clusterEnabled =
    hostConfig ? mlx && hostConfig.mlx ? clusterMode && (hostConfig.mlx.clusterMode.enable or false);
  linkPrep = osConfig.system.clusterLinkPrep;
in
{
  config = lib.mkIf clusterEnabled {
    # Cross-repo safety gate (INC-17076/17077 failure class). This bridge only
    # carries the wired ceilings into nix-ai's env; the values themselves — and
    # the exact-value sudoers grants the watcher needs to apply them — live in
    # system.clusterLinkPrep. Enabling clusterMode while that system module is
    # off pushes a null/standalone ceiling with no grant and no link: the
    # decorative-guard bug this module exists to kill. Refuse to build the
    # half-wired configuration rather than ship an inert guard.
    assertions = [
      {
        assertion = osConfig.system.clusterLinkPrep.enable;
        message = ''
          programs.mlx.clusterMode is enabled but system.clusterLinkPrep.enable
          is false. The cluster wired-memory ceiling guard would be inert: no
          exact-value sudoers grant is emitted and no Thunderbolt link is
          configured, so the nix-ai watcher/lifecycle commands cannot apply the
          ceiling (INC-17076/17077). Enable system.clusterLinkPrep on this host.
        '';
      }
    ];

    programs.mlx.clusterMode = {
      wiredLimitMb = linkPrep.clusterWiredLimitMb;
      inherit (linkPrep) standaloneWiredLimitMb;

      # Expected per-rank shard size for nix-ai's memory-headroom precondition
      # rung (rank_start_preconditions_ok, cluster-link-guards.sh): refuses a
      # rank start unless free+reclaimable memory covers this many MB. Closes
      # the chain a 2026-08-01 incident hit on both Macs the same afternoon — a
      # rank started into ~72 GiB of unreclaimed wired Metal memory left over
      # from a prior crashed rank, leaked an RDMA protection domain, repeated
      # 5x, halted. The nix-ai module default is 0 (disabled); this host sets
      # it explicitly because a default-off rung protects nothing. Both hosts
      # run the SAME catalog model (modelCatalogKey = "glm47-reap50", see
      # lib/hosts/mac-studio.nix / macbook-m4.nix) at the same shard size, so
      # one shared value covers both roles.
      #
      # Measured live (Studio, both ranks serving, verified by a real
      # completion): wired = 3271199 pages x 16384 bytes = ~49.9 GiB. 56000 MB
      # (~54.7 GiB) adds headroom for KV cache and activations on top of that —
      # deliberately not the bare shard size, which would refuse starts that
      # would have succeeded and, with the rung's dwell escalation, turn a
      # transient into a halt.
      shardMemoryMb = 56000;

      # EXPERIMENT (INC-17070, remove once resolved): disables the prompt cache
      # on both cluster ranks to isolate a multi-request pipeline hang. The only
      # knob the clusterMode module exposes for rank server args is
      # extraServerArgs (appended verbatim to mlx_lm.server ProgramArguments).
      extraServerArgs = [
        "--prompt-cache-size"
        "0"
      ];
    };
  };
}
