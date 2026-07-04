#!/usr/bin/env bash
# Remove Apple built-in apps under /Applications by CFBundleIdentifier.
#
# Args: one or more CFBundleIdentifiers to remove. Runs as root during
# nix-darwin activation — see modules/darwin/apps/remove-builtin-apps.nix.
# Matched by bundle id (robust to Apple's display-name quirks, e.g. Keynote
# shipping as "Keynote Creator Studio.app"). Only /Applications is in scope;
# /System/Applications is SIP-protected and cannot be removed. Idempotent.
set -eu

_removed=0
for _app in /Applications/*.app; do
  # Skip the literal glob if /Applications ever has no .app entries.
  [ -e "$_app" ] || continue
  _bid=$(/usr/bin/defaults read "$_app/Contents/Info" CFBundleIdentifier 2>/dev/null) || continue
  for _target in "$@"; do
    [ "$_bid" = "$_target" ] || continue
    if rm -rf "$_app" 2>/dev/null; then
      echo "[remove-builtin-apps] removed $_app ($_bid)"
      _removed=$((_removed + 1))
    else
      echo "[remove-builtin-apps] WARN: could not remove $_app ($_bid)" >&2
    fi
    break
  done
done
echo "[remove-builtin-apps] complete ($_removed removed)"
