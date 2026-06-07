#!/usr/bin/env bash
#
# Apple Silicon — volatile sysctl apply (boot + activation)
#
# Re-applies the iogpu/vm sysctls that reset to their default on every reboot.
# Driven by environment variables from the nix-darwin module; an empty value
# means "leave the macOS default untouched". Best-effort: a failure logs a
# warning but never aborts. Invoked both by the RunAtLoad launchd daemon and by
# the activation script. Native macOS CLIs only.

prefix="[apple-silicon-sysctls]"
log() { echo "$prefix INFO $*"; }
warn() { echo "$prefix WARN $*" >&2; }

# iogpu.wired_limit_mb — GPU wired-memory ceiling.
if [ -n "${WIRED_LIMIT_MB:-}" ]; then
  if /usr/sbin/sysctl -w "iogpu.wired_limit_mb=${WIRED_LIMIT_MB}" >/dev/null; then
    log "iogpu.wired_limit_mb=${WIRED_LIMIT_MB}"
  else
    warn "sysctl iogpu.wired_limit_mb failed"
  fi
fi

# iogpu.wired_lwm_mb — low-water mark (optional, rarely set).
if [ -n "${WIRED_LWM_MB:-}" ]; then
  if /usr/sbin/sysctl -w "iogpu.wired_lwm_mb=${WIRED_LWM_MB}" >/dev/null 2>&1; then
    log "iogpu.wired_lwm_mb=${WIRED_LWM_MB}"
  else
    warn "sysctl iogpu.wired_lwm_mb failed"
  fi
fi

# vm.compressor_mode — compression/swap policy (optional; usually needs a
# reboot to fully take effect, so a runtime write here is best-effort).
if [ -n "${VM_COMPRESSOR_MODE:-}" ]; then
  if /usr/sbin/sysctl -w "vm.compressor_mode=${VM_COMPRESSOR_MODE}" >/dev/null 2>&1; then
    log "vm.compressor_mode=${VM_COMPRESSOR_MODE}"
  else
    warn "sysctl vm.compressor_mode failed (may require a reboot)"
  fi
fi

exit 0
