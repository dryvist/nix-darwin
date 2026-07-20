# Cluster wired-ceiling wiring (split out for the per-file byte cap).
#
# The cluster wired ceilings (coordinator 90000 / worker 80000) and their
# day-restore counterparts (coordinator 118000 / worker 0) live ONCE in
# nix-darwin's system.clusterLinkPrep (clusterWiredLimitMb + the computed,
# read-only dayWiredLimitMb), which also emits the exact-value sudoers grants.
# This module feeds those SAME values into nix-ai's programs.mlx.clusterMode so
# the link watcher and cluster-join/cluster-detach commands actually receive
# CLUSTER_WIRED_LIMIT_MB / CLUSTER_DAY_WIRED_LIMIT_MB in their environment.
#
# Without this bridge the pin is a no-op: the guard against the 2026-07-19
# WindowServer watchdog panic (INC-17076) and the Studio contention panic class
# (INC-17062) was believed deployed but was decorative — the sudoers grants
# existed with nothing configured to invoke them.
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
    # off pushes a null/day ceiling with no grant and no link configured: the
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
      inherit (linkPrep) dayWiredLimitMb;

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
