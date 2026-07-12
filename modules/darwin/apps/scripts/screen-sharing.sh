# shellcheck shell=bash
# Enable the macOS Screen Sharing (VNC) launchd service and start it if it
# is not already running.
#
# nix-darwin ships no first-class option for this (not one of its services.*
# modules), so this goes through `launchctl enable` + `launchctl kickstart`
# directly — the standard command-line equivalent of toggling Screen Sharing
# on in System Settings > General > Sharing. macOS system binaries
# (launchctl, grep) are called by absolute path — writeShellApplication
# restricts PATH to runtimeInputs, and launchctl is a macOS-only tool not in
# nixpkgs.
#
# Guarded: `enable` is a harmless no-op when already enabled. `kickstart` is
# only called when the service isn't already running, so a re-run (every
# darwin-rebuild) never drops an active Screen Sharing session by force
# restarting it.

service="system/com.apple.screensharing"

echo "[screen-sharing] enabling ${service}..."
/bin/launchctl enable "$service"

if /bin/launchctl print "$service" 2>/dev/null | /usr/bin/grep -q "state = running"; then
  echo "[screen-sharing] ${service} already running; nothing to do"
else
  echo "[screen-sharing] starting ${service}..."
  /bin/launchctl kickstart "$service"
fi
