#!/usr/bin/env bash
#
# Idempotently creates + configures the dedicated `openbao.keychain-db`
# keychain. Runs as a NATIVE user-domain LaunchAgent (RunAtLoad) — not from a
# root-run activation script. Confirmed on real hardware: crossing from root
# into the login user's securityd session via `sudo -u`/`launchctl asuser`
# creates the keychain FILE fine (that's a plain filesystem op) but silently
# fails to persist the keychain SEARCH-LIST update (a session-scoped securityd
# operation) — the command reports success but the change never sticks. A
# genuine user LaunchAgent needs no privilege crossing at all, which is why
# this script takes the password FILE PATH as an argument (not the raw value
# — the value never appears in `ps` output, only a path does) and reads it
# with the same permissions the LaunchAgent process already has.
#
# Usage: openbao-keychain-setup.sh <keychain-path> <password-file>

set -euo pipefail

prefix="[openbao-keychain-setup]"
log() { echo "$prefix INFO $*"; }

keychain_path="${1:?usage: openbao-keychain-setup.sh <keychain-path> <password-file>}"
password_file="${2:?usage: openbao-keychain-setup.sh <keychain-path> <password-file>}"
password="$(cat "${password_file}")"

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
