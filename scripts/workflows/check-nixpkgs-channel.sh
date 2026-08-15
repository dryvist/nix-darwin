#!/usr/bin/env bash
# check-nixpkgs-channel.sh — Warn if any nixpkgs input diverges from its Hydra channel HEAD.
#
# Emits a GitHub Actions ::warning:: annotation when a locked nixpkgs rev is not the
# Hydra-evaluated channel rev. A mismatch means binary cache coverage may be sparse,
# causing slow builds (source builds instead of fast narinfo hits).
#
# Checks EVERY channel-tracking nixpkgs input, not just the `*-darwin` one. The
# previous version selected on `test("-darwin$")`, which silently skipped
# `nixpkgs-unstable` — the input that feeds nix-home's python overlay, and the one
# whose drift let an uncached arrow-cpp into the closure and blew the CI timeout.
# Any ref resolvable under channels.nixos.org qualifies; inputs pinned to a bare
# rev or a non-channel branch have no channel to compare against and are skipped.
#
# Not a hard failure: the channel URL may lag briefly after a Hydra evaluation.
# The warning is sufficient signal for a PR author to decide whether to update first.

set -euo pipefail

# Every distinct channel-style ref in the lockfile. `nixpkgs-unstable` and
# `nixpkgs-<release>-darwin` are both real channels; sort -u because several
# inputs commonly track the same one.
#
# Plain `while read`, not `mapfile`: this runs on macos-latest, where bash may
# be 3.2, and `mapfile` is a bash 4 builtin that would fail the step outright
# under `set -e`.
CHANNEL_NAMES=""
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  CHANNEL_NAMES="$CHANNEL_NAMES$ref
"
done <<EOF
$(jq -r '
    .nodes | to_entries[]
    | select(.value.locked.repo? == "nixpkgs")
    | .value.original.ref? // empty
  ' flake.lock | sort -u)
EOF

if [ -z "$CHANNEL_NAMES" ]; then
  echo "No channel-tracking nixpkgs input found in flake.lock — skipping check"
  exit 0
fi

echo "$CHANNEL_NAMES" | while IFS= read -r CHANNEL_NAME; do
  [ -n "$CHANNEL_NAME" ] || continue
  CHANNEL_URL="https://channels.nixos.org/$CHANNEL_NAME/git-revision"

  channel_rev=$(curl --connect-timeout 5 --max-time 15 -sfL "$CHANNEL_URL" || echo "")
  if [ -z "$channel_rev" ]; then
    echo "$CHANNEL_NAME: no channel revision at $CHANNEL_URL — not a published channel, skipping"
    continue
  fi

  # Report every input on this ref: two inputs can track one channel at
  # different revs (nix-ai and nix-home both follow nixpkgs-unstable), and it is
  # precisely that divergence we want surfaced.
  while read -r input_name flake_rev; do
    [ -n "$flake_rev" ] || continue
    if [ "$flake_rev" != "$channel_rev" ]; then
      echo "::warning::$input_name ($CHANNEL_NAME) pinned to ${flake_rev:0:12} but channel is at ${channel_rev:0:12} — binary cache may be sparse; expect a slower build"
    else
      echo "$input_name ($CHANNEL_NAME) ${flake_rev:0:12} matches Hydra channel HEAD — binary cache coverage expected"
    fi
  done < <(
    jq -r --arg ref "$CHANNEL_NAME" '
      .nodes | to_entries[]
      | select(.value.original.ref? == $ref)
      | "\(.key) \(.value.locked.rev)"
    ' flake.lock
  )
done
