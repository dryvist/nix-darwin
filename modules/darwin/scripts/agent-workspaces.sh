#!/usr/bin/env bash
# agent-workspaces - lay out each automation identity's workspace folders.
#
# <root> is the shared agent volume. It is group-writable by `agent` with the
# setgid bit, so an identity can recreate its own folder after the operator
# wipes it (agent-launch does that at every launch). Under it, each identity
# owns <root>/<identity> at mode 700, with one folder per tool it runs.
#
# A root that is not mounted yet is skipped, never created: the APFS volume
# daemon (apfs-volumes.nix) mounts it, and a plain directory created here
# would hide the volume's mount point.
#
# Usage: agent-workspaces <root> <identity> [<tool>...]

root="${1:?usage: agent-workspaces <root> <identity> [tool...]}"
identity="${2:?usage: agent-workspaces <root> <identity> [tool...]}"
shift 2

if [ ! -d "$root" ]; then
  echo "[agent-workspaces] $root is not mounted; skipping $identity" >&2
  exit 0
fi

chgrp agent "$root"
chmod 2775 "$root"
install -d -o "$identity" -g staff -m 700 "$root/$identity"
for tool in "$@"; do
  install -d -o "$identity" -g staff -m 700 "$root/$identity/$tool"
done
