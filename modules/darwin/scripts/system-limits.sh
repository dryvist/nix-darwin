#!/usr/bin/env bash
#
# System resource limits — apply (boot + activation)
#
# Driven by environment variables from the nix-darwin module; an empty value
# means "leave the macOS default untouched". Best-effort: a failure logs a
# warning but never aborts. Native macOS CLIs only.

prefix="[system-limits]"
log() { echo "$prefix INFO $*"; }
warn() { echo "$prefix WARN $*" >&2; }

apply_sysctl() {
  local key="$1" value="$2"
  [ -n "${value}" ] || return 0
  if /usr/sbin/sysctl -w "${key}=${value}" >/dev/null 2>&1; then
    log "${key}=${value}"
  else
    warn "sysctl ${key} failed"
  fi
}

apply_sysctl kern.maxfiles "${MAXFILES:-}"
apply_sysctl kern.maxfilesperproc "${MAXFILESPERPROC:-}"
apply_sysctl kern.maxproc "${MAXPROC:-}"
apply_sysctl kern.maxprocperuid "${MAXPROCPERUID:-}"

# Global launchd open-file limit (soft hard).
if [ -n "${LAUNCHCTL_MAXFILES_SOFT:-}" ] && [ -n "${LAUNCHCTL_MAXFILES_HARD:-}" ]; then
  if /bin/launchctl limit maxfiles "${LAUNCHCTL_MAXFILES_SOFT}" "${LAUNCHCTL_MAXFILES_HARD}" >/dev/null 2>&1; then
    log "launchctl limit maxfiles ${LAUNCHCTL_MAXFILES_SOFT} ${LAUNCHCTL_MAXFILES_HARD}"
  else
    warn "launchctl limit maxfiles failed"
  fi
fi

exit 0
