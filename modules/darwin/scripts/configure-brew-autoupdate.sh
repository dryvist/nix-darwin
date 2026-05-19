#!/usr/bin/env bash
#
# Configure brew autoupdate LaunchAgent on every darwin-rebuild switch.
#
# Determines the brew user (SUDO_USER or console owner), then (re)installs the
# homebrew/autoupdate LaunchAgent with the configured interval and flags.
#
# `sudo -u … -H` is required: without -H, HOME stays at /var/root (the
# activation script's HOME) and brew's bootsnap loader fails with EACCES
# trying to read /var/root/Library/Caches/Homebrew/bootsnap/.../load-path-cache.
# -H rewrites HOME to the target user's home so bootsnap uses
# ~/Library/Caches/Homebrew/bootsnap instead.

set -uo pipefail

# All external utilities are called via absolute paths (BSD variants on macOS)
# so writeShellApplication's runtimeInputs can stay empty — no Nix-managed
# coreutils needed, and no risk of GNU stat shadowing BSD stat.

prefix="[brew-autoupdate]"
log() { echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') $prefix INFO $*"; }
warn() { echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') $prefix WARN $*" >&2; }

interval="${AUTOUPDATE_INTERVAL:-}"
if [ -z "$interval" ]; then
    warn "AUTOUPDATE_INTERVAL not set; skipping"
    exit 0
fi

log "Configuring brew autoupdate (interval=${interval}s, --upgrade --greedy --cleanup)..."

# /usr/bin/stat: force macOS BSD stat — bare 'stat' may resolve to GNU stat
# (Nix coreutils), which ignores -f '%Su' and prints the full file report.
brew_user="${SUDO_USER:-$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null)}"
if [ -z "$brew_user" ] || [ "$brew_user" = "root" ]; then
    warn "Cannot determine brew user — skipping brew autoupdate configuration"
    exit 0
fi

if ! test -x /opt/homebrew/bin/brew; then
    warn "/opt/homebrew/bin/brew not found — skipping autoupdate configuration"
    exit 0
fi

# Delete existing autoupdate config (no-op if absent). Best-effort: the start
# below will surface the real outcome.
/usr/bin/sudo -u "$brew_user" -H /opt/homebrew/bin/brew autoupdate delete 2>/dev/null || true

# Start fresh with current flags. A failure here means the LaunchAgent was
# not (re)installed; the activation must still succeed (existing LaunchAgent
# from a prior run, if any, keeps running), but the warning makes the failure
# visible instead of silent.
if /usr/bin/sudo -u "$brew_user" -H /opt/homebrew/bin/brew autoupdate start "$interval" --upgrade --greedy --cleanup; then
    log "brew autoupdate LaunchAgent (re)installed for $brew_user"
else
    warn "brew autoupdate start failed (exit $?); any existing LaunchAgent for $brew_user remains in place"
fi

exit 0
