# shellcheck shell=bash
# A live cluster rank needs the VM runner's memory; reconcile its LaunchDaemon.

launchctl_bin=/bin/launchctl
rank_live_bin="${MLX_CLUSTER_RANK_LIVE_BIN:?}"
label="${VM_RUNNER_LABEL:?}"
plist="${VM_RUNNER_PLIST:?}"
log() { echo "cluster-vm-runner-gate: $*"; }

clustered=0
if "$rank_live_bin"; then
  clustered=1
else
  rc=$?
  if [ "$rc" -gt 1 ]; then
    log "cluster state undetermined (rc=$rc); leaving $label unchanged"
    exit 0
  fi
fi

if [ "$clustered" -eq 1 ]; then
  if "$launchctl_bin" print "system/$label" >/dev/null 2>&1; then
    if "$launchctl_bin" bootout "system/$label"; then
      log "clustered; stopped $label"
    else
      log "clustered; bootout failed, retrying next tick"
    fi
  else
    log "clustered; $label is not loaded"
  fi
elif "$launchctl_bin" print "system/$label" >/dev/null 2>&1; then
  log "not clustered; $label is already loaded"
elif [ ! -f "$plist" ]; then
  log "not clustered; $label is not installed"
elif "$launchctl_bin" bootstrap system "$plist"; then
  log "not clustered; started $label"
else
  log "not clustered; bootstrap failed, retrying next tick"
fi
