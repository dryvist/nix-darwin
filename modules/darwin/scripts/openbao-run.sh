#!/usr/bin/env bash
# openbao-run - the OpenBao replacement for `doppler run`.
#
# Fetches named secrets from OpenBao via an AppRole login and execs a command
# with them injected as environment variables - exactly what `doppler run` did,
# with no external dependency. Secret-zero (the OpenBao address + a domain
# AppRole's role_id/secret_id) is read from the AMBIENT ENVIRONMENT, published
# per-domain by the openbao keychain resolver (launchctl setenv
# <DOMAIN>_VAULT_ROLE_ID / _SECRET_ID). No fetched secret is ever written to
# disk; the values live only in the environment of the exec'd child.
#
# Usage:
#   openbao-run --domain local-llm \
#     --secret ENV_NAME=<kv-path>#<field> [--secret ...] \
#     -- <command> [args...]
#
# Example (the llm-large gate):
#   openbao-run --domain local-llm \
#     --secret LLM_LARGE_BEARER_TOKEN=ai/llm#LLM_LARGE_BEARER_TOKEN \
#     --secret AWS_ACME_ACCESS_KEY_ID=platform/acme#AWS_ACME_ACCESS_KEY_ID \
#     --secret AWS_ACME_SECRET_ACCESS_KEY=platform/acme#AWS_ACME_SECRET_ACCESS_KEY \
#     --secret LLM_GATE_AWS_REGION=platform/acme#region \
#     -- caddy run --config /nix/store/....Caddyfile --adapter caddyfile
#
# `pkgs.writeShellApplication` wraps this in `set -euo pipefail` and lints it,
# so this file omits its own `set` boilerplate.

prefix="[openbao-run]"
die() {
  echo "$prefix ERROR $*" >&2
  exit 1
}

domain=""
keychain=""
declare -a specs=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      domain="${2:?--domain needs a value}"
      shift 2
      ;;
    --keychain)
      keychain="${2:?--keychain needs a path}"
      shift 2
      ;;
    --secret)
      specs+=("${2:?--secret needs ENV=path#field}")
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *) die "unknown argument: $1 (expected --domain, --keychain, --secret, or --)" ;;
  esac
done

[ -n "$domain" ] || die "no --domain given"
[ "${#specs[@]}" -gt 0 ] || die "no --secret mappings given"
[ "$#" -gt 0 ] || die "no command after -- to exec"

# Secret-zero resolution: env first (for interactive/CI callers), then the
# macOS keychain (for unattended launchd agents with no Doppler session). The
# keychain is the doppler-free delivery: an auto-readable keychain unlocks at
# login, so `security find-generic-password -s <name> -w <keychain>` returns
# the value with no password prompt. `security` is hardcoded to its system path
# (not a nixpkgs package).
resolve() {
  local name="$1" val
  val="$(printenv "$name" 2>/dev/null || true)"
  if [ -z "$val" ] && [ -n "$keychain" ]; then
    val="$(/usr/bin/security find-generic-password -s "$name" -w "$keychain" 2>/dev/null || true)"
  fi
  printf '%s' "$val"
}

# OpenBao address: honor either the OpenBao-native or the legacy Vault name.
addr="$(resolve BAO_ADDR)"
[ -n "$addr" ] || addr="$(resolve VAULT_ADDR)"
[ -n "$addr" ] || die "BAO_ADDR not in environment or keychain '$keychain'"

# This domain's AppRole role_id/secret_id, named e.g. LLM_GATE_VAULT_ROLE_ID
# (domain uppercased, - -> _).
env_prefix="${domain^^}"
env_prefix="${env_prefix//-/_}"
role_id="$(resolve "${env_prefix}_VAULT_ROLE_ID")"
secret_id="$(resolve "${env_prefix}_VAULT_SECRET_ID")"
[ -n "$role_id" ] || die "${env_prefix}_VAULT_ROLE_ID not in environment or keychain '$keychain'"
[ -n "$secret_id" ] || die "${env_prefix}_VAULT_SECRET_ID not in environment or keychain '$keychain'"

export BAO_ADDR="$addr"

# AppRole login -> a short-lived token, used only for the reads below. Never
# persisted; scoped to this process.
token="$(bao write -field=token auth/approle/login \
  role_id="$role_id" secret_id="$secret_id")" \
  || die "AppRole login failed for domain '$domain' at $addr"
export BAO_TOKEN="$token"

# Fetch each mapping and export it. Format: ENV_NAME=<kv-path>#<field>.
# KV v2 mount is `secret`; paths are given mount-relative (e.g. ai/llm).
for spec in "${specs[@]}"; do
  if [[ ! "$spec" =~ ^([A-Za-z_][A-Za-z0-9_]*)=([^#]+)#(.+)$ ]]; then
    die "bad --secret spec '$spec' (want ENV=path#field)"
  fi
  env_name="${BASH_REMATCH[1]}"
  kv_path="${BASH_REMATCH[2]}"
  field="${BASH_REMATCH[3]}"
  value="$(bao kv get -mount=secret -field="$field" "$kv_path")" \
    || die "read failed: secret/$kv_path field '$field' (policy or path missing?)"
  export "$env_name=$value"
done

# Drop the login token from the child's environment - it only needed the
# exported secret values, not OpenBao access.
unset BAO_TOKEN

exec "$@"
