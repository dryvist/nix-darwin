# shellcheck shell=bash
# Keep the VM runner's memory free for the MLX cluster; reconcile its LaunchDaemon.
#
# The runner starts only on a positive "not clustered": the rank is not live AND
# the cluster link is down AND the cluster is not armed. Every other answer
# stops it: a live rank, an undetermined rank state (no console session, e.g.
# at boot before auto-login), an armed cluster or an up link (the window
# between arming and rank start), or state files that cannot be read. The state
# files are only ever a reason to stop, never to start, so a stale file delays
# the runner but cannot put the cluster at risk. Every tick logs its decision.

launchctl_bin="${VM_RUNNER_LAUNCHCTL_BIN:-/bin/launchctl}"
rank_live_bin="${MLX_CLUSTER_RANK_LIVE_BIN:?}"
label="${VM_RUNNER_LABEL:?}"
plist="${VM_RUNNER_PLIST:?}"
log() { echo "cluster-vm-runner-gate: $*"; }

# Prints why the runner must stop; prints nothing when it may run.
stop_reason() {
  local rc=0 console_user state_dir link armed
  "$rank_live_bin" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) echo "cluster rank is live"; return ;;
    1) ;;
    *) echo "cluster rank state undetermined (rc=$rc)"; return ;;
  esac
  state_dir="${MLX_CLUSTER_STATE_DIR:-}"
  if [ -z "$state_dir" ]; then
    console_user=$(/usr/bin/stat -f %Su /dev/console 2>/dev/null || true)
    state_dir="/Users/$console_user/Library/Application Support/mlx-cluster"
  fi
  if ! link=$(tr -d '[:space:]' < "$state_dir/link-state" 2>/dev/null); then
    echo "cluster link-state unreadable"; return
  fi
  if ! armed=$(jq -r '.armed' "$state_dir/peer-state.json" 2>/dev/null); then
    echo "cluster peer-state unreadable"; return
  fi
  [ "$link" = down ] || { echo "cluster link-state is '$link'"; return; }
  [ "$armed" = false ] || { echo "cluster armed is '$armed'"; return; }
}

reason=$(stop_reason)
loaded=0
"$launchctl_bin" print "system/$label" >/dev/null 2>&1 && loaded=1

if [ -n "$reason" ]; then
  if [ "$loaded" -eq 0 ]; then
    log "$reason; $label is not loaded"
  elif "$launchctl_bin" bootout "system/$label"; then
    log "$reason; stopped $label"
  else
    log "$reason; bootout failed, retrying next tick"
  fi
elif [ "$loaded" -eq 1 ]; then
  log "not clustered; $label is already loaded"
elif [ ! -f "$plist" ]; then
  log "not clustered; $label is not installed"
elif "$launchctl_bin" bootstrap system "$plist"; then
  log "not clustered; started $label"
else
  log "not clustered; bootstrap failed, retrying next tick"
fi
