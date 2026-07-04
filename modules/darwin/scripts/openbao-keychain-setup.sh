#!/usr/bin/env bash
#
# Idempotently creates + configures the dedicated `openbao.keychain-db`
# keychain. Invoked from the nix-darwin activation script (which runs as
# root) via:
#   sudo -u <user> env OPENBAO_KEYCHAIN_PASSWORD="$password" \
#     openbao-keychain-setup.sh <keychain-path>
# Keychains are per-user, so this must actually run AS the login user, not
# root — `sudo -u` handles that. Root reads the sops-decrypted
# /run/secrets/OPENBAO_KEYCHAIN_PASSWORD (root:wheel 0400) itself and passes
# the value straight through as a one-shot env var on the `sudo` command
# line; it's never written to a user-readable file. Best-effort per step
# with clear logging, matching apple-silicon-tunables.sh's style.
#
# Usage: openbao-keychain-setup.sh <keychain-path>

set -euo pipefail

prefix="[openbao-keychain-setup]"
log() { echo "$prefix INFO $*"; }

keychain_path="${1:?usage: openbao-keychain-setup.sh <keychain-path>}"
password="${OPENBAO_KEYCHAIN_PASSWORD:?OPENBAO_KEYCHAIN_PASSWORD must be set in the environment}"

if [ -f "${keychain_path}" ]; then
  log "keychain already exists at ${keychain_path} — skipping create"
else
  /usr/bin/security create-keychain -p "${password}" "${keychain_path}"
  log "created ${keychain_path}"
fi

# 72h auto-lock (259200s); no -l so it does NOT also lock on sleep — the
# keychain's lock state is the sole access boundary (see terraform-proxmox
# docs/SECRETS_HIERARCHY.md), and the 72h timeout is the only gate wanted.
/usr/bin/security set-keychain-settings -t 259200 "${keychain_path}"
log "set 72h auto-lock timeout"

# Add to the user's keychain search list if not already present, preserving
# every existing entry (a plain `-s <path>` REPLACES the whole list).
if /usr/bin/security list-keychains -d user | grep -qF "${keychain_path}"; then
  log "already in the user keychain search list"
else
  mapfile -t existing < <(/usr/bin/security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')
  /usr/bin/security list-keychains -d user -s "${existing[@]}" "${keychain_path}"
  log "added to the user keychain search list"
fi
