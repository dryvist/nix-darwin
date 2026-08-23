#!/usr/bin/env bash
# Cribl Edge activation helper.
#
# Ensures the mutable data + log directories exist and are owned by the
# service account before launchd starts the daemon. Runs on every
# darwin-rebuild activation so non-root serviceUser configurations work
# regardless of whether packs are declared.
#
# Arguments (bound by the Nix caller in cribl-edge.nix):
#   $1 = dataDir (e.g. /opt/cribl-data)
#   $2 = serviceUser:serviceGroup chown target (e.g. root:wheel)
#   $3 = mode ("standalone" | "managed"); optional, defaults to managed
#
# In standalone mode it also retires any leftover managed-mode enrolment
# state. That used to happen inside the start wrapper, on every single start,
# to decide at run time which mode it was in. The mode is known at build time,
# so the retirement is a one-shot migration and belongs in activation — which
# is what lets the standalone daemon exec `cribl server` directly instead of
# going through a wrapper.

set -euo pipefail

DATA_DIR="${1:?dataDir required}"
OWNER="${2:?owner:group required}"
MODE="${3:-managed}"

mkdir -p "$DATA_DIR" "$DATA_DIR/logs"

if [ "$MODE" = "standalone" ]; then
  # An enrolled instance keeps talking to its former leader and ignores the
  # declarative config on disk, so these three files must not survive a switch
  # to standalone. Moved rather than deleted: if the switch was a mistake, the
  # enrolment can be put back by hand, and a timestamped copy says when it was
  # retired.
  retired="$DATA_DIR/retired-managed-state"
  for f in "$DATA_DIR/.enrolled" \
           "$DATA_DIR/local/_system/instance.yml" \
           "$DATA_DIR/local/edge/instance.yml"; do
    if [ -e "$f" ]; then
      mkdir -p "$retired"
      mv "$f" "$retired/$(basename "$f").$(date +%Y%m%d%H%M%S)"
      echo "[cribl-edge-activate] standalone: retired managed-state file $f"
    fi
  done
fi

/usr/sbin/chown -R "$OWNER" "$DATA_DIR"
