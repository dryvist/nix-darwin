# shellcheck shell=bash
# Cluster VM-runner gate: one reconcile pass that keeps the macOS VM runner
# out of a live cluster rank's way.
#
# The runner's VM is memory the cluster needs while a rank serves, so a live
# rank boots the runner daemon out and a torn-down cluster boots it back in.
#
# A RECONCILER, NOT A HOOK. It runs on a timer and drives the runner toward
# live cluster state every tick, the same design as the maintenance-window
# reconciler: it cannot delay a rank start or a teardown, and a missed edge
# converges on the next tick.
#
# "Clustered" is the one definition every consumer shares, mlx-cluster-rank-live.
# Undetermined (no GUI launchd domain) is treated as not clustered and logged
# as such, the same policy the maintenance window uses.
#
# Every tick logs its decision. A failed launchctl call logs and retries on the
# next tick; nothing here blocks anything.
#
# Environment (module-injected):
#   MLX_CLUSTER_RANK_LIVE_BIN  the single "a rank is live" detector
#   VM_RUNNER_LABEL            launchd label of the VM runner daemon
#   VM_RUNNER_PLIST            its plist, bootstrapped back in on teardown
#   MLX_CLUSTER_LAUNCHCTL_BIN  launchctl path (default /bin/launchctl; test seam)

launchctl_bin="${MLX_CLUSTER_LAUNCHCTL_BIN:-/bin/launchctl}"
label="${VM_RUNNER_LABEL:?VM_RUNNER_LABEL not set}"
plist="${VM_RUNNER_PLIST:?VM_RUNNER_PLIST not set}"
rank_live_bin="${MLX_CLUSTER_RANK_LIVE_BIN:?MLX_CLUSTER_RANK_LIVE_BIN not set}"

log() { echo "cluster-vm-runner-gate: $*"; }

# rank-live writes its own verdict to stderr; this records what it means here.
rc=0
"$rank_live_bin" || rc=$?
case "$rc" in
  0) clustered=1 ;;
  1) clustered=0 ;;
  *)
    clustered=0
    log "cluster state UNDETERMINED (rc=$rc); treating this host as not clustered"
    ;;
esac

loaded=0
if "$launchctl_bin" print "system/$label" > /dev/null 2>&1; then
  loaded=1
fi

if [ "$clustered" -eq 1 ]; then
  if [ "$loaded" -eq 1 ]; then
    if "$launchctl_bin" bootout "system/$label"; then
      log "clustered - stopped $label; VM runner released to the cluster"
    else
      log "clustered - bootout of $label FAILED; retrying next tick"
    fi
  else
    log "clustered - $label not loaded; nothing to stop"
  fi
elif [ "$loaded" -eq 1 ]; then
  log "not clustered - $label loaded; nothing to start"
elif [ -f "$plist" ]; then
  if "$launchctl_bin" bootstrap system "$plist"; then
    log "not clustered - started $label"
  else
    log "not clustered - bootstrap of $label FAILED; retrying next tick"
  fi
else
  log "not clustered - $label not installed; nothing to start"
fi
