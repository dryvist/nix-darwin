# shellcheck shell=bash
# Pre-activation gate — refuse to change this system while this host is clustered.
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
# A host is clustered when either of these holds:
#   - the rank agent is live (mlx-cluster-rank-live exits 0), or
#   - link-state reads `up` and peer-state.json reports `"armed": true`.
# Both files sit in the cluster state directory under CLUSTER_USER_HOME. The
# link check allows only when link-state is missing, reads `down`, or reads `up`
# with armed false. Any other link state refuses.
#
# Environment:
#   MLX_CLUSTER_RANK_LIVE_BIN  path to mlx-cluster-rank-live (injected by the
#                              module; a test seam otherwise)
#   CLUSTER_USER_HOME          home directory of the primary user, which holds
#                              the cluster state directory (injected by the
#                              module; a test seam otherwise)

rank_live_bin="${MLX_CLUSTER_RANK_LIVE_BIN:?MLX_CLUSTER_RANK_LIVE_BIN not set}"
user_home="${CLUSTER_USER_HOME:?CLUSTER_USER_HOME not set}"
state_dir="$user_home/Library/Application Support/mlx-cluster"
link_file="$state_dir/link-state"
peer_file="$state_dir/peer-state.json"

# Parsed with bash built-ins only. peer-state.json is checked for the shape the
# gate reads, not for full JSON validity.
object_re='^[[:space:]]*[{].*[}][[:space:]]*$'
armed_key='"armed"'
armed_re='"armed"[[:space:]]*:[[:space:]]*(true|false)[[:space:]]*[,}]'

refuse_link() {
  echo "cluster-rebuild-gate: REFUSING to activate — $1." >&2
  echo "cluster-rebuild-gate: Unlock by running cluster-detach, which writes link-state down, then rebuild." >&2
  echo "cluster-rebuild-gate: There is deliberately no override." >&2
  exit 1
}

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
    rank_note="no cluster rank is live on this host"
    ;;
  *)
    # Treated as not-clustered, and SAID so rather than folded silently into
    # the line above: a rank cannot run without the GUI domain that hosts it,
    # so this is the right call, but a reader deserves to know the gate
    # allowed on an unanswered question rather than on a measured "stopped".
    rank_note="cluster state UNDETERMINED (rc=$rc, no GUI launchd domain to ask); a rank cannot be running without one"
    ;;
esac

if [ ! -d "$user_home" ]; then
  echo "cluster-rebuild-gate: REFUSING to activate — CLUSTER_USER_HOME is not a directory, so cluster state cannot be read." >&2
  exit 1
fi

if [ ! -e "$link_file" ] && [ ! -L "$link_file" ]; then
  link_note="link-state file absent, so no cluster link is up"
elif ! link_state="$(< "$link_file")"; then
  refuse_link "link-state cannot be read"
elif [ "$link_state" = "down" ]; then
  link_note="link-state down"
elif [ "$link_state" = "up" ]; then
  if ! peer_state="$(< "$peer_file")"; then
    refuse_link "link-state is up and peer-state.json cannot be read"
  fi
  if ! [[ $peer_state =~ $object_re ]]; then
    refuse_link "link-state is up and peer-state.json is not a JSON object"
  fi
  stripped="${peer_state//"$armed_key"/}"
  if (( ${#peer_state} - ${#stripped} != ${#armed_key} )); then
    refuse_link "link-state is up and peer-state.json does not hold exactly one armed key"
  fi
  if ! [[ $peer_state =~ $armed_re ]]; then
    refuse_link "link-state is up and peer-state.json armed is not a true or false literal"
  fi
  if [ "${BASH_REMATCH[1]}" = "true" ]; then
    refuse_link "link-state is up and peer-state reports armed"
  fi
  link_note="link-state up and peer-state armed is false"
else
  refuse_link "link-state holds an unrecognised value"
fi

echo "cluster-rebuild-gate: ALLOWING — $rank_note; $link_note."
