#!/usr/bin/env bash
# Disable the screensaver's idle timer for the auto-login user on this host.
#
# Idle time is stored ByHost
# (~/Library/Preferences/ByHost/com.apple.screensaver.<hwid>.plist), which
# `system.defaults.CustomUserPreferences` cannot reach — that writes the
# plain, non-ByHost domain. `-currentHost` is the documented escape hatch,
# already used the same way for NSStatusItemSpacing in
# modules/darwin/system-ui.nix.
#
# Activation itself runs as root, so a bare `defaults -currentHost` here
# would write root's ByHost domain, not the console user's, and silently do
# nothing for the wall. `sudo -u "$WALL_USER"` targets the auto-login user
# explicitly.
#
# This host drives the server-room wall monitor: the screensaver must never
# engage.

set -uo pipefail

WALL_USER="${1:?usage: wall-screensaver-disable.sh <username>}"

if sudo -u "$WALL_USER" defaults -currentHost write com.apple.screensaver idleTime 0; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Screensaver idle time disabled for $WALL_USER"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to disable screensaver idle time for $WALL_USER" >&2
fi
