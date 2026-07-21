#!/usr/bin/env bash
# Cribl Edge post-activation restart gate.
#
# Force the running daemon onto the just-installed declarative config. The
# extraActivation phase writes local/edge/*.yml BEFORE the launchd phase, but
# two things defeat that on their own:
#   1. The launchd phase does not reliably restart Edge on the plist sha change
#      (observed: pids unchanged across a `darwin-rebuild switch`).
#   2. A running Edge periodically autosaves its in-memory config back over
#      local/edge/ (and default/edge/), clobbering the freshly-installed files
#      before any restart — so the next restart reloads stale config.
# Running in postActivation (after the launchd phase loads the current plist)
# and restarting seconds after config install closes the autosave-clobber
# window. Marker-gated so unrelated switches don't gratuitously restart the
# daemon. PQ buffering + services.launchdSelfHeal cover the brief restart gap.
#
# Arguments (bound by the Nix caller in cribl-edge.nix):
#   $1 = dataDir (e.g. /opt/cribl-data)
#   $2 = expected declared-config sha256
#   $3 = launchd label (e.g. com.nix-darwin.cribl-edge)
#   $4 = serviceUser:serviceGroup chown target for the marker (e.g. root:wheel)

set -euo pipefail

DATA_DIR="${1:?dataDir required}"
EXPECTED_SHA="${2:?expected sha required}"
LABEL="${3:?launchd label required}"
OWNER="${4:?owner:group required}"

MARKER="$DATA_DIR/.declared-config-sha"

if [ "$(cat "$MARKER" 2>/dev/null)" != "$EXPECTED_SHA" ]; then
  /bin/launchctl kickstart -k "system/$LABEL" 2>/dev/null || true
  printf '%s' "$EXPECTED_SHA" >"$MARKER"
  /usr/sbin/chown "$OWNER" "$MARKER" 2>/dev/null || true
fi
