# shellcheck shell=bash
# Pre-activation gate — refuse to change this system while a cluster rank is live.
#
# Runs first in `system.activationScripts.preActivation`, so it covers BOTH
# entry points that can swap the running system out from under a rank:
# `darwin-rebuild switch` and a direct `/nix/var/nix/profiles/system/activate`.
# Both end in the same activate script, which is why the gate lives there
# rather than in a wrapper around one command.
#
# Why refuse at all: activation restarts agents, rewrites the link
# configuration and replaces the mlx/JACCL stack the two ranks agreed on when
# they rendezvoused. A jaccl group cannot re-admit a rank, so a mid-session
# activation does not degrade the cluster, it ends it — and each failed
# re-formation afterwards costs a kernel RDMA protection domain that only a
# reboot returns.
#
# THERE IS NO OVERRIDE. No environment variable, no flag, no marker to delete.
# Cluster teardown is the unlock, and teardown is a real action with real
# consequences the operator should be taking deliberately: unplug the
# Thunderbolt cable, or turn cluster mode off. An override would be used, and
# the domains it spent would not come back.
#
# Environment:
#   MLX_CLUSTER_RANK_LIVE_BIN  path to mlx-cluster-rank-live (injected by the
#                              module; a test seam otherwise)

rank_live_bin="${MLX_CLUSTER_RANK_LIVE_BIN:?MLX_CLUSTER_RANK_LIVE_BIN not set}"

rc=0
"$rank_live_bin" || rc=$?

case "$rc" in
  0)
    echo "cluster-rebuild-gate: REFUSING to activate — a cluster rank is live on this host." >&2
    echo "cluster-rebuild-gate: Activating now would replace the stack this rank rendezvoused on and end the" >&2
    echo "cluster-rebuild-gate: cluster mid-session; re-forming costs RDMA protection domains a reboot alone returns." >&2
    echo "cluster-rebuild-gate: Unlock by tearing the cluster down — unplug the Thunderbolt cable, or turn cluster" >&2
    echo "cluster-rebuild-gate: mode off — then rebuild. There is deliberately no override." >&2
    exit 1
    ;;
  1)
    echo "cluster-rebuild-gate: ALLOWING — no cluster rank is live on this host."
    ;;
  *)
    # Treated as not-clustered, and SAID so rather than folded silently into
    # the line above: a rank cannot run without the GUI domain that hosts it,
    # so this is the right call, but a reader deserves to know the gate
    # allowed on an unanswered question rather than on a measured "stopped".
    echo "cluster-rebuild-gate: ALLOWING — cluster state UNDETERMINED (rc=$rc, no GUI launchd domain to ask); a rank cannot be running without one."
    ;;
esac
