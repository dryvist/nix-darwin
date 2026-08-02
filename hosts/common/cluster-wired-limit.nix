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

      # UNATTENDED AUTO-REBOOT: only where the host can actually finish booting
      # without a human. 0 disables it (halt-and-alert only).
      #
      # An auto-reboot is self-healing ONLY if the machine returns to service
      # by itself. With FileVault enabled and no auto-unlock, a reboot parks at
      # the pre-boot unlock prompt and STAYS DOWN until someone types a
      # password — converting a recoverable halt into an outage of unbounded
      # length, and doing it unattended, at night, on a laptop that may not be
      # near its owner. That is strictly worse than the halt it is clearing.
      #
      # Measured 2026-08-01: `fdesetup status` reports FileVault On on the
      # laptop and Off on the headless host, and only the headless host has an
      # autoLoginUser set. So the headless host reboots straight back into
      # service and keeps the feature; the laptop must not.
      #
      # Gate on the real precondition rather than a hostname: a host may enable
      # this only if it boots unattended. If FileVault is ever disabled on the
      # laptop (or an auto-unlock is configured), flip this and say so here.
      pdAutoRebootWindowSecs = if hostConfig.isServer then 21600 else 0;

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

      # wiredCeilingMb (dryvist/nix-ai#1481) is DELIBERATELY LEFT UNSET (0 =
      # disabled). Any value here must come from the layered-ceiling model in
      # the private docs repo, never from an ad-hoc estimate: a ceiling derived
      # without it reaps healthy ranks.
      #
      # From the definition sites, per that page's clustered formula:
      #   F_rank(N) = W_shard + L1_buf + B_cache + N * C_seq
      # with W_shard ~49 GiB (catalog weightGb 98.0 sharded over two ranks),
      # L1_buf 12 GiB (bufferCacheLimitGb), B_cache 8 GiB (cacheMemoryMb 8192):
      #   F_rank(N) = 69 GiB + N * C_seq
      # The floor is 69 GiB before ONE request is served, so a 75 GiB ceiling
      # leaves 6 GiB for all concurrency and fires at N=1 on the declared
      # context. It reaps healthy work.
      #
      # The premise was also wrong, not merely the number. That page gives
      #   N_max(clustered) = floor((L0_wired - W_shard - L1_buf - B_cache)/C_seq)
      # i.e. usage is DESIGNED to run up toward L0_wired. No wired threshold
      # below L0_wired can separate legitimate load from a leak, so a runtime
      # wired ceiling is the wrong instrument at any value.
      #
      # What today's watchdog reset actually shows is that L0_wired itself is
      # too high: the compositor draws GPU memory from the same pool, and at
      # 96.7 GiB of a 100 GiB ceiling it could not get a Metal command buffer.
      # The layered model treats L0_wired as fully available to MLX and does not
      # account for that competitor. The fix belongs at the single definition
      # site — appleSiliconTunables.maxLocalLlmGb — not in a second ad-hoc
      # ceiling here, and it is a capacity decision for the operator.

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
