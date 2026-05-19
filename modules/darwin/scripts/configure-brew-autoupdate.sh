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

prefix="[brew-autoupdate]"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $prefix INFO $*"; }
warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') $prefix WARN $*" >&2; }

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

# Delete existing autoupdate config (may not exist); start fresh with current flags.
/usr/bin/sudo -u "$brew_user" -H /opt/homebrew/bin/brew autoupdate delete 2>/dev/null || true
/usr/bin/sudo -u "$brew_user" -H /opt/homebrew/bin/brew autoupdate start "$interval" --upgrade --greedy --cleanup || true

exit 0
