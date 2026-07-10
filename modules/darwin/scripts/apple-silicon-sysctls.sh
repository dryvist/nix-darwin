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
#
# At early boot the IOGPU sysctl node can register a few seconds after launchd
# fires this RunAtLoad daemon. A single write then races: `sysctl -w` fails (or
# the value fails to stick) and the daemon exits, leaving the ceiling at the OS
# default (0) until the next `darwin-rebuild switch`. Retry a bounded number of
# times, verifying the read-back each attempt, so a boot-time race self-heals
# and every boot leaves exactly one INFO/WARN line in the log.
if [ -n "${WIRED_LIMIT_MB:-}" ]; then
  attempts="${WIRED_LIMIT_ATTEMPTS:-30}"
  delay="${WIRED_LIMIT_RETRY_DELAY:-2}"
  n=1
  while true; do
    if /usr/sbin/sysctl -w "iogpu.wired_limit_mb=${WIRED_LIMIT_MB}" >/dev/null 2>&1 &&
      [ "$(/usr/sbin/sysctl -n iogpu.wired_limit_mb 2>/dev/null || true)" = "${WIRED_LIMIT_MB}" ]; then
      log "iogpu.wired_limit_mb=${WIRED_LIMIT_MB} (attempt ${n}/${attempts})"
      break
    fi
    if [ "${n}" -ge "${attempts}" ]; then
      warn "sysctl iogpu.wired_limit_mb still not ${WIRED_LIMIT_MB} after ${attempts} attempts"
      break
    fi
    warn "iogpu.wired_limit_mb not ready (attempt ${n}/${attempts}); retrying in ${delay}s"
    n=$((n + 1))
    /bin/sleep "${delay}"
  done
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
