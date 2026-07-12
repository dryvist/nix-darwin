#!/usr/bin/env bash
#
# AWS `credential_process` provider — replaces a static aws-vault base key
# with short-lived STS creds minted on demand by OpenBao's AWS secrets engine
# (assumed_role). Reads the terraform-apply AppRole's role_id/secret_id from
# the openbao.keychain-db keychain (same read pattern as
# openbao-keychain-resolver.sh — keychain LOCK STATE is the access boundary).
#
# Usage (as an ~/.aws/config credential_process line):
#   credential_process = openbao-aws-creds tf-proxmox
#
# Caches the emitted STS creds at 0600 under ~/.cache/openbao-aws/, keyed by
# role name, and only re-authenticates + re-mints when the cached lease is
# within SAFETY_MARGIN_SECONDS of expiry. `aws`/terraform invoke
# credential_process on every API call, so without this cache a single
# terraform run would hammer OpenBao with AppRole logins + fresh STS leases.
# An mkdir-based atomic lock (no `flock` — not shipped on macOS) collapses
# concurrent invocations racing on a cold/expired cache into one fetch.
#
# `pkgs.writeShellApplication` (used to build this script) wraps it in
# `set -euo pipefail` and runs shellcheck regardless of this file's own
# content (see openbao-keychain-resolver.sh for the same note).
#
# macOS-only: `/bin/date -v` below is BSD date syntax, not GNU.

readonly KEYCHAIN="${HOME}/Library/Keychains/openbao.keychain-db"
readonly CACHE_DIR="${HOME}/.cache/openbao-aws"
readonly ROLE="${1:?usage: openbao-aws-creds <aws-role-name>}"
readonly CACHE_FILE="${CACHE_DIR}/${ROLE}.json"
readonly LOCK_DIR="${CACHE_FILE}.lock"
# Refresh this far before actual STS expiry so a long-running command never
# gets handed creds that expire mid-request.
readonly SAFETY_MARGIN_SECONDS=600

prefix="[openbao-aws-creds]"
warn() { echo "$prefix WARN $*" >&2; }
die() { echo "$prefix ERROR $*" >&2; exit 1; }

read_item() {
  local service="$1" account="$2"
  # A missing keychain item (locked keychain, not-yet-seeded role) is an
  # EXPECTED outcome here, not a script failure — see the resolver script's
  # note on why `|| true` is required under set -e.
  /usr/bin/security find-generic-password -s "${service}" -a "${account}" -w "${KEYCHAIN}" 2>/dev/null || true
}

# Fast path: a cached lease that's still comfortably valid — no network call.
cache_is_fresh() {
  [ -f "${CACHE_FILE}" ] || return 1
  local expiration exp_epoch now_epoch
  expiration="$(jq -r '.Expiration // empty' "${CACHE_FILE}" 2>/dev/null)" || return 1
  [ -n "${expiration}" ] || return 1
  exp_epoch="$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "${expiration}" +%s 2>/dev/null)" || return 1
  now_epoch="$(/bin/date -u +%s)"
  [ "$((exp_epoch - now_epoch))" -gt "${SAFETY_MARGIN_SECONDS}" ]
}

if cache_is_fresh; then
  cat "${CACHE_FILE}"
  exit 0
fi

# Cache miss/stale: acquire a short-lived atomic lock so concurrent
# invocations (terraform issues many AWS calls in parallel) don't each
# independently log in and mint a fresh STS lease. mkdir is atomic on a local
# filesystem; whichever process wins does the fetch, the rest wait for it.
attempt=0
until /bin/mkdir "${LOCK_DIR}" 2>/dev/null; do
  attempt=$((attempt + 1))
  if [ "${attempt}" -ge 100 ]; then
    warn "lock ${LOCK_DIR} held past ~10s, reclaiming (assuming a prior holder crashed)"
    /bin/rm -rf "${LOCK_DIR}"
    continue
  fi
  sleep 0.1
  # Someone else may have refreshed the cache while we were waiting on it.
  if cache_is_fresh; then
    cat "${CACHE_FILE}"
    exit 0
  fi
done
trap '/bin/rm -rf "${LOCK_DIR}"' EXIT

# Re-check after acquiring the lock — another process may have just won it
# and refreshed the cache before we got here.
if cache_is_fresh; then
  cat "${CACHE_FILE}"
  exit 0
fi

bao_addr="$(read_item "openbao" "bao_addr")"
role_id="$(read_item "openbao/terraform-apply" "role_id")"
secret_id="$(read_item "openbao/terraform-apply" "secret_id")"
if [ -z "${bao_addr}" ] || [ -z "${role_id}" ] || [ -z "${secret_id}" ]; then
  die "openbao/bao_addr or openbao/terraform-apply role_id/secret_id not found in ${KEYCHAIN} — keychain locked or not yet seeded"
fi

login_resp="$(curl -sf --max-time 10 -X POST \
  -d "{\"role_id\":\"${role_id}\",\"secret_id\":\"${secret_id}\"}" \
  "${bao_addr}/v1/auth/approle/login")" || die "AppRole login to ${bao_addr} failed"
token="$(jq -r '.auth.client_token // empty' <<<"${login_resp}")"
[ -n "${token}" ] || die "AppRole login returned no client_token"

sts_resp="$(curl -sf --max-time 10 -H "X-Vault-Token: ${token}" \
  "${bao_addr}/v1/aws/sts/${ROLE}")" || die "reading aws/sts/${ROLE} failed"

access_key="$(jq -r '.data.access_key // empty' <<<"${sts_resp}")"
secret_key="$(jq -r '.data.secret_key // empty' <<<"${sts_resp}")"
session_token="$(jq -r '.data.security_token // empty' <<<"${sts_resp}")"
lease_seconds="$(jq -r '.lease_duration // empty' <<<"${sts_resp}")"
if [ -z "${access_key}" ] || [ -z "${secret_key}" ] || [ -z "${session_token}" ] || [ -z "${lease_seconds}" ]; then
  die "aws/sts/${ROLE} response missing access_key/secret_key/security_token/lease_duration"
fi

expiration="$(/bin/date -u -v+"${lease_seconds}"S +'%Y-%m-%dT%H:%M:%SZ')"

/bin/mkdir -p "${CACHE_DIR}"
umask 077
jq -n \
  --arg akid "${access_key}" \
  --arg sak "${secret_key}" \
  --arg tok "${session_token}" \
  --arg exp "${expiration}" \
  '{Version: 1, AccessKeyId: $akid, SecretAccessKey: $sak, SessionToken: $tok, Expiration: $exp}' \
  >"${CACHE_FILE}"
/bin/chmod 0600 "${CACHE_FILE}"
cat "${CACHE_FILE}"
