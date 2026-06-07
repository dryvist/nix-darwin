#!/usr/bin/env bash
#
# Network stack tuning — apply (boot + activation)
#
# Driven by environment variables from the nix-darwin module; an empty value
# means "leave the macOS default untouched". Best-effort: a failure logs a
# warning but never aborts. Native macOS CLIs only.

prefix="[network-tuning]"
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

apply_sysctl kern.ipc.maxsockbuf "${MAXSOCKBUF:-}"
apply_sysctl net.inet.tcp.sendspace "${TCP_SENDSPACE:-}"
apply_sysctl net.inet.tcp.recvspace "${TCP_RECVSPACE:-}"
apply_sysctl net.inet.tcp.win_scale_factor "${TCP_WIN_SCALE_FACTOR:-}"
apply_sysctl net.inet.tcp.autorcvbufmax "${TCP_AUTORCVBUFMAX:-}"
apply_sysctl net.inet.tcp.autosndbufmax "${TCP_AUTOSNDBUFMAX:-}"

exit 0
