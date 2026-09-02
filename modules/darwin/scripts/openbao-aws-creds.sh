#!/usr/bin/env bash
#
# AWS `credential_process` provider — replaces a static aws-vault base key
# with short-lived STS creds minted on demand by OpenBao's AWS secrets engine
# (assumed_role). Secret-zero is read from the AMBIENT ENVIRONMENT, not a local
# keychain: VAULT_ADDR + the terraform AppRole's role_id/secret_id. In practice
# these are injected by running terragrunt under `doppler run` (the iac secret
# store holds the OpenBao bootstrap; OpenBao serves everything else).
#
# Usage (as an ~/.aws/config credential_process line):
#   credential_process = openbao-aws-creds tf-proxmox
# The invoking process must carry VAULT_ADDR, OPENBAO_APPROLE_TERRAFORM_ROLE_ID
# and OPENBAO_APPROLE_TERRAFORM_SECRET_ID in its environment (credential_process
# children inherit the terragrunt/`doppler run` env).
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
# `set -euo pipefail` and runs shellcheck, so this file omits its own.
#
# macOS-only: `/bin/date -v` below is BSD date syntax, not GNU.

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

# The lock dir lives INSIDE the cache dir, so the cache dir must exist before
# the first lock attempt (mkdir without -p fails on a missing parent, which
# would spin the acquisition loop forever on a cold start).
/bin/mkdir -p "${CACHE_DIR}"
/bin/chmod 0700 "${CACHE_DIR}"

# Cache miss/stale: acquire a short-lived atomic lock so concurrent
# invocations (terraform issues many AWS calls in parallel) don't each
# independently log in and mint a fresh STS lease. mkdir is atomic on a local
# filesystem; whichever process wins does the fetch, the rest wait for it.
#
# The lock dir carries the owning PID in a "pid" file. A blind time-based
# reclaim (the prior behavior) can fire on a holder that is merely slow, not
# dead — leaving two processes believing they hold the lock at once. Reclaim
# only when the recorded PID is provably dead (kill -0 fails); a live holder
# past the wait budget is a hard failure, not a force-evict.
readonly LOCK_PID_FILE="${LOCK_DIR}/pid"
attempt=0
until /bin/mkdir "${LOCK_DIR}" 2>/dev/null; do
  owner_pid="$(cat "${LOCK_PID_FILE}" 2>/dev/null || echo "")"
  if [ -n "${owner_pid}" ] && ! kill -0 "${owner_pid}" 2>/dev/null; then
    warn "lock ${LOCK_DIR} held by dead pid ${owner_pid}, reclaiming"
    /bin/rm -rf "${LOCK_DIR}"
    continue
  fi
  attempt=$((attempt + 1))
  if [ "${attempt}" -ge 100 ]; then
    die "lock ${LOCK_DIR} held by live pid ${owner_pid:-unknown} past ~10s — refusing to force-evict a live holder"
  fi
  sleep 0.1
  # Someone else may have refreshed the cache while we were waiting on it.
  if cache_is_fresh; then
    cat "${CACHE_FILE}"
    exit 0
  fi
done
echo "$$" >"${LOCK_PID_FILE}"
trap '/bin/rm -rf "${LOCK_DIR}"' EXIT

# Re-check after acquiring the lock — another process may have just won it
# and refreshed the cache before we got here.
if cache_is_fresh; then
  cat "${CACHE_FILE}"
  exit 0
fi

bao_addr="${VAULT_ADDR:-}"
role_id="${OPENBAO_APPROLE_TERRAFORM_ROLE_ID:-}"
secret_id="${OPENBAO_APPROLE_TERRAFORM_SECRET_ID:-}"
if [ -z "${bao_addr}" ] || [ -z "${role_id}" ] || [ -z "${secret_id}" ]; then
  die "VAULT_ADDR / OPENBAO_APPROLE_TERRAFORM_ROLE_ID / OPENBAO_APPROLE_TERRAFORM_SECRET_ID not in environment — run terragrunt under 'doppler run' so the OpenBao bootstrap is injected"
fi

# Credential travels via a private payload on stdin, never argv (argv is
# visible to any local process via ps).
login_resp="$(jq -n --arg r "${role_id}" --arg s "${secret_id}" '{role_id: $r, secret_id: $s}' \
  | curl -sf --max-time 10 -X POST --data-binary @- \
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
