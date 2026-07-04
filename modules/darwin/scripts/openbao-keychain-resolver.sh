#!/usr/bin/env bash
#
# OpenBao keychain resolver — runs as a launchd user agent (RunAtLoad + a
# periodic StartInterval, well inside the 72h auto-lock window). Reads each
# domain's AppRole role_id/secret_id (plus the shared BAO_ADDR) from the
# dedicated `openbao.keychain-db` keychain and publishes them into the login
# session's launchd environment via `launchctl setenv`, so any process
# subsequently spawned in that GUI session (a terminal, an ansible-playbook
# run) inherits them ambiently — no keychain access, no vault knowledge,
# required in the consuming process itself.
#
# The keychain's LOCK STATE is the entire access boundary (see terraform-proxmox
# docs/SECRETS_HIERARCHY.md): if it's locked, `security find-generic-password`
# fails for that item and this script simply skips it (best-effort, matches
# the Ansible role's own per-domain skip-when-unset behavior) — it does NOT
# prompt for a password itself (a launchd agent has no place to show one).
#
# `public` is deliberately NOT resolved here — it ships ambiently via its own
# non-keychain-gated channel (see docs/SECRETS_HIERARCHY.md), so it never
# needs an unlock at all.

readonly KEYCHAIN="${HOME}/Library/Keychains/openbao.keychain-db"
prefix="[openbao-keychain-resolver]"
log() { echo "$prefix INFO $*"; }
warn() { echo "$prefix WARN $*" >&2; }

# Domains this resolver publishes env vars for — must match
# ansible-proxmox-apps roles/openbao_secrets/defaults/main.yml exactly (same
# domain name, same *_VAULT_ROLE_ID/*_VAULT_SECRET_ID convention).
readonly DOMAINS=(observability local-cloud monitoring media local-llm)

read_item() {
  local service="$1" account="$2"
  /usr/bin/security find-generic-password -s "${service}" -a "${account}" -w "${KEYCHAIN}" 2>/dev/null
}

set_env() {
  local var="$1" value="$2"
  [ -n "${value}" ] || return 0
  /bin/launchctl setenv "${var}" "${value}"
}

# BAO_ADDR is shared across every domain (the OpenBao ingress FQDN).
bao_addr="$(read_item "openbao" "bao_addr")"
if [ -z "${bao_addr}" ]; then
  warn "openbao/bao_addr not found in ${KEYCHAIN} — keychain locked or not yet seeded; skipping all domains"
  exit 0
fi
set_env "BAO_ADDR" "${bao_addr}"
log "BAO_ADDR published"

for domain in "${DOMAINS[@]}"; do
  role_id="$(read_item "openbao/${domain}" "role_id")"
  secret_id="$(read_item "openbao/${domain}" "secret_id")"
  if [ -z "${role_id}" ] || [ -z "${secret_id}" ]; then
    warn "openbao/${domain} role_id/secret_id not both present — skipping"
    continue
  fi
  # Env var prefix: domain name uppercased, hyphens -> underscores
  # (local-cloud -> LOCAL_CLOUD), matching the Ansible role's naming.
  var_prefix="$(echo "${domain}" | tr '[:lower:]-' '[:upper:]_')"
  set_env "${var_prefix}_VAULT_ROLE_ID" "${role_id}"
  set_env "${var_prefix}_VAULT_SECRET_ID" "${secret_id}"
  log "${domain} published as ${var_prefix}_VAULT_ROLE_ID/_SECRET_ID"
done
