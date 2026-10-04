#!/usr/bin/env bash
#
# System resource limits — apply (boot + activation)
#
# Driven by environment variables from the nix-darwin module; an empty value
# means "leave the macOS default untouched". The root daemon applies kernel
# sysctls and the system launchd limit; launchctl asuser applies the same limit
# to an active GUI login's launchd context.

prefix="[system-limits]"
log() { echo "$prefix INFO $*"; }
warn() { echo "$prefix WARN $*" >&2; }
launchctl_bin="${SYSTEM_LIMITS_LAUNCHCTL:-/bin/launchctl}"
stat_bin="${SYSTEM_LIMITS_STAT:-/usr/bin/stat}"

apply_sysctl() {
  local key="$1" value="$2"
  [ -n "${value}" ] || return 0
  if /usr/sbin/sysctl -w "${key}=${value}" >/dev/null 2>&1; then
    log "${key}=${value}"
  else
    warn "sysctl ${key} failed"
  fi
}

if [ "${SYSTEM_LIMITS_APPLY_SYSCTLS:-1}" = "1" ]; then
  apply_sysctl kern.maxfiles "${MAXFILES:-}"
  apply_sysctl kern.maxfilesperproc "${MAXFILESPERPROC:-}"
  apply_sysctl kern.maxproc "${MAXPROC:-}"
  apply_sysctl kern.maxprocperuid "${MAXPROCPERUID:-}"
fi

# Global launchd open-file limit (soft hard).
if [ -n "${LAUNCHCTL_MAXFILES_SOFT:-}" ] && [ -n "${LAUNCHCTL_MAXFILES_HARD:-}" ]; then
  if "$launchctl_bin" limit maxfiles "${LAUNCHCTL_MAXFILES_SOFT}" "${LAUNCHCTL_MAXFILES_HARD}" >/dev/null 2>&1; then
    log "launchctl limit maxfiles ${LAUNCHCTL_MAXFILES_SOFT} ${LAUNCHCTL_MAXFILES_HARD}"
  else
    warn "launchctl limit maxfiles failed"
    exit 1
  fi

  if ! console_uid=$("$stat_bin" -f%u /dev/console) || [[ ! "$console_uid" =~ ^[0-9]+$ ]]; then
    warn "could not determine console user for GUI maxfiles limit"
    exit 1
  fi

  if [ "$console_uid" -eq 0 ]; then
    log "no GUI console user; GUI maxfiles limit deferred until login"
  elif "$launchctl_bin" asuser "$console_uid" "$launchctl_bin" limit maxfiles "${LAUNCHCTL_MAXFILES_SOFT}" "${LAUNCHCTL_MAXFILES_HARD}" >/dev/null 2>&1; then
    log "launchctl asuser ${console_uid} limit maxfiles ${LAUNCHCTL_MAXFILES_SOFT} ${LAUNCHCTL_MAXFILES_HARD}"
  else
    warn "GUI launchctl limit maxfiles failed for console uid ${console_uid}"
    exit 1
  fi
fi

exit 0
