# shellcheck shell=bash
# Shared by pf-hardening-load and pf-hardening-trial; the module prepends this file to both.
#
# Every decision line goes to the file log (PF_HARDENING_LOG) and to the unified log under the
# tag pf-hardening, so the file log is complete whether launchd or activation runs the script.
# snapshot() appends a bounded, read-only record of pf state to the file log, so pf state can be
# read from the shipped log without root.
#
# Environment (test seams; defaults are the system paths):
#   PF_HARDENING_PFCTL, PF_HARDENING_LOGGER, PF_HARDENING_LSOF, PF_HARDENING_LOG, PF_HARDENING_NOW

PFCTL=${PF_HARDENING_PFCTL:-/sbin/pfctl}
LOGGER=${PF_HARDENING_LOGGER:-/usr/bin/logger}
LSOF=${PF_HARDENING_LSOF:-/usr/sbin/lsof}
LOG=${PF_HARDENING_LOG:-/var/log/pf-hardening.log}
ENFORCED_ANCHOR=com.apple/nix-hardening
INERT_ANCHOR=nix-hardening
# Lines per snapshot section and characters per line.
SNAPSHOT_LINES=200
SNAPSHOT_WIDTH=300

now() { echo "${PF_HARDENING_NOW:-$(date -u +%s)}"; }
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

say() {
  printf '%s pf-hardening: %s\n' "$(iso "$(now)")" "$1" >>"$LOG"
  "$LOGGER" -t pf-hardening "$1" </dev/null || true
}

fail() {
  say "FAILED: $1"
  exit 1
}

# Each line of a command's output, prefixed and cut, at most SNAPSHOT_LINES lines.
section() {
  local name=$1
  shift
  { "$@" 2>&1 || true; } | head -n "$SNAPSHOT_LINES" | cut -c1-"$SNAPSHOT_WIDTH" \
    | sed "s|^|snapshot $name: |" >>"$LOG" || true
}

snapshot() {
  section info sh -c "\"\$0\" -s info | grep -E '^Status:|current entries'" "$PFCTL"
  section "rules $ENFORCED_ANCHOR" "$PFCTL" -a "$ENFORCED_ANCHOR" -s rules
  section "rules $INERT_ANCHOR" "$PFCTL" -a "$INERT_ANCHOR" -s rules
  section anchors "$PFCTL" -s Anchors
  section "anchors com.apple" "$PFCTL" -a com.apple -s Anchors
}

listeners() {
  section "listen tcp" "$LSOF" -nP -iTCP -sTCP:LISTEN
  section "listen udp" "$LSOF" -nP -iUDP
}

# True when the anchor holds no rules. A failed rule listing counts only when the parent's anchor
# list also omits the name (pf drops an anchor that holds no rules).
flushed() {
  local name=$1 rules parent anchors anchor
  if rules=$("$PFCTL" -a "$name" -s rules 2>/dev/null); then
    [ -z "$rules" ]
    return
  fi
  parent=${name%/*}
  [ "$parent" != "$name" ] || parent=
  anchors=$("$PFCTL" ${parent:+-a "$parent"} -s Anchors 2>/dev/null) || return 1
  while read -r anchor; do
    [ "$anchor" != "$name" ] && [ "$anchor" != "${name##*/}" ] || return 1
  done <<<"$anchors"
}
