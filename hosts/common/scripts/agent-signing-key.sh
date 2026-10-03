#!/usr/bin/env bash
# agent-signing-key - give this identity a commit-signing key.
#
# Runs at home-manager activation as the identity itself. The key is an
# unencrypted ed25519 SSH key: sessions sign unattended, and the account's
# home is owner-only (agent-home-perms). The private half never leaves this
# home. The public half is printed on every activation, because the home is
# unreadable to the operator, who registers it on GitHub as a signing key.
#
# Usage: agent-signing-key <private-key-path>

key="${1:?usage: agent-signing-key <private-key-path>}"

if [ ! -f "$key" ]; then
  mkdir -p "$(dirname "$key")"
  chmod 700 "$(dirname "$key")"
  ssh-keygen -q -t ed25519 -N "" -C "$(id -un) git signing" -f "$key"
fi

echo "[agent-signing-key] $(id -un) signs commits with: $(cat "$key.pub")"
