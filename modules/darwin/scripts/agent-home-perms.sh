#!/usr/bin/env bash
# agent-home-perms - make each automation identity's home owner-only.
#
# Every automation identity sits in `staff` (gid 20) as its PRIMARY group —
# the same primary group the operator has — and `createHome` leaves the home
# at mode 750. Group-read on 750 therefore lets every agent account traverse
# every other agent's home, and the operator's, and read anything left at the
# home-manager default of 644/755.
#
# That was verified by execution rather than inference: running as the
# lower-trust identity successfully read the operator's credential notes, the
# operator's checkouts, and the other identity's forge configuration.
#
# 700 closes all of it in one step and needs no chown. Re-grouping the
# accounts would not, on its own — existing files keep gid 20 until they are
# moved, so the exposure would survive the rename. The operator still reaches
# these homes with sudo, exactly as before.
#
# A home that does not exist yet is skipped, not created: account creation is
# `users.users.<name>.createHome`, and this must not race it.
#
# Usage: agent-home-perms <home-dir> [<home-dir>...]

if [ "$#" -eq 0 ]; then
  echo "agent-home-perms: no home directories given" >&2
  exit 2
fi

for agentHome in "$@"; do
  [ -d "$agentHome" ] || continue
  chmod 700 "$agentHome"
done

# Declaratively enforce permissions on operator's private agent notes directory
# Ensures all regular files (including dotfiles and nested files) are mode 0600
# and subdirectories are mode 0700.
for operatorHome in /Users/*; do
  localDir="${operatorHome}/AGENTS.local.d"
  if [ -d "$localDir" ]; then
    chmod 700 "$localDir"
    find "$localDir" -mindepth 1 -type f -exec chmod 600 {} +
    find "$localDir" -mindepth 1 -type d -exec chmod 700 {} +
  fi
done
