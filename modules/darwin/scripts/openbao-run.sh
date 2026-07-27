#!/usr/bin/env bash
# openbao-run - the OpenBao replacement for `doppler run`.
#
# Fetches named secrets from OpenBao via an AppRole login and execs a command
# with them injected as environment variables - exactly what `doppler run` did,
# with no external dependency. Secret-zero (the OpenBao address + a domain
# AppRole's role_id/secret_id) is read from the AMBIENT ENVIRONMENT first; for
# unattended launchd agents with no ambient session, `--env-file` names a
# 0600 user-owned file sourced before resolution. macOS keychains are NOT a
# secret-zero path: only the login keychain auto-unlocks at login, and custom
# keychains start locked in every new security session, so a keychain-backed
# agent can never start unattended (the 2026-07 llm-gate outage; the old
# `--keychain` flag was removed for exactly that reason). No fetched secret is
# ever written to disk; the values live only in the environment of the exec'd
# child.
#
# Usage:
#   openbao-run --domain local-llm \
#     [--env-file <0600-path>] \
#     --secret [<mount>:]ENV_NAME=<kv-path>#<field> [--secret ...] \
#     -- <command> [args...]
#
# Each --secret reads from the KV v2 mount named by the optional leading
# `<mount>:` prefix, defaulting to $OPENBAO_KV_MOUNT (itself defaulting to
# "secret" for backward compat) when the prefix is omitted. This lets one
# invocation mix mounts, e.g. an internal-only secret alongside one on the
# internet-reachable secrets-external mount (see the acme example below).
#
# Example (the llm-large gate):
#   openbao-run --domain local-llm \
#     --secret LLM_LARGE_BEARER_TOKEN=ai/llm#LLM_LARGE_BEARER_TOKEN \
#     --secret secrets-external:AWS_ACME_ACCESS_KEY_ID=platform/acme#AWS_ACME_ACCESS_KEY_ID \
#     --secret secrets-external:AWS_ACME_SECRET_ACCESS_KEY=platform/acme#AWS_ACME_SECRET_ACCESS_KEY \
#     --secret secrets-external:LLM_GATE_AWS_REGION=platform/acme#region \
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
env_file=""
declare -a specs=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      domain="${2:?--domain needs a value}"
      shift 2
      ;;
    --env-file)
      env_file="${2:?--env-file needs a path}"
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
    *) die "unknown argument: $1 (expected --domain, --env-file, --secret, or --)" ;;
  esac
done

[ -n "$domain" ] || die "no --domain given"
[ "${#specs[@]}" -gt 0 ] || die "no --secret mappings given"
[ "$#" -gt 0 ] || die "no command after -- to exec"

# Secret-zero env file: sourced before resolution so unattended launchd agents
# get their bootstrap (BAO_ADDR + AppRole creds) with no keychain and no
# ambient session. Must be user-owned 0600 or 0400 — refuse anything looser,
# since the file authenticates to OpenBao.
if [ -n "$env_file" ]; then
  [ -f "$env_file" ] || die "--env-file '$env_file' does not exist (seed it: BAO_ADDR + <DOMAIN>_VAULT_ROLE_ID/_SECRET_ID)"
  perms="$(/usr/bin/stat -f '%Lp' "$env_file")"
  [ "$perms" = "600" ] || [ "$perms" = "400" ] || die "--env-file '$env_file' must be mode 0600 or 0400 (is $perms)"
  set -a
  # shellcheck source=/dev/null
  . "$env_file"
  set +a
fi

# Secret-zero resolution: the environment (ambient for interactive/CI callers,
# or populated by the --env-file source above for unattended agents).
resolve() {
  printenv "$1" 2>/dev/null || true
}

src="environment"
[ -n "$env_file" ] && src="environment or env file $env_file"

# OpenBao address: honor either the OpenBao-native or the legacy Vault name.
addr="$(resolve BAO_ADDR)"
[ -n "$addr" ] || addr="$(resolve VAULT_ADDR)"
[ -n "$addr" ] || die "BAO_ADDR not in $src"

# This domain's AppRole role_id/secret_id, named e.g. LLM_GATE_VAULT_ROLE_ID
# (domain uppercased, - -> _).
env_prefix="${domain^^}"
env_prefix="${env_prefix//-/_}"
role_id="$(resolve "${env_prefix}_VAULT_ROLE_ID")"
secret_id="$(resolve "${env_prefix}_VAULT_SECRET_ID")"
[ -n "$role_id" ] || die "${env_prefix}_VAULT_ROLE_ID not in $src"
[ -n "$secret_id" ] || die "${env_prefix}_VAULT_SECRET_ID not in $src"

# ALL OpenBao HTTP goes through /usr/bin/curl — the APPLE PLATFORM binary,
# hardcoded path, never a nixpkgs curl. macOS Local Network privacy silently
# denies NON-platform binaries LAN access in GUI-session launchd contexts
# ("connect: no route to host"), while platform binaries are exempt. Verified
# live 2026-07-17 on macOS 26.5.2 from the same gui/501 one-shot: the
# nix-store `bao` CLI got EHOSTUNREACH on the very login /usr/bin/curl
# completed with HTTP 200 (ssh sessions are also exempt, which is why shell
# tests never reproduced it). There is no supported CLI/MDM pre-approval for
# Local Network TCC, so the fix is to keep the network path on the exempt
# platform binary. jq (no network) parses the responses.

# AppRole login -> a short-lived token, used only for the reads below. Never
# persisted; scoped to this process. Credentials travel via a private
# temporary payload on stdin (never argv).
login_payload="$(jq -n --arg r "$role_id" --arg s "$secret_id" \
  '{role_id: $r, secret_id: $s}')"
token="$(printf '%s' "$login_payload" \
  | /usr/bin/curl -sSf --max-time 30 -X POST -H 'Content-Type: application/json' \
      --data-binary @- "$addr/v1/auth/approle/login" \
  | jq -re '.auth.client_token')" \
  || die "AppRole login failed for domain '$domain' at $addr"

# KV v2 mount, per-secret override via an optional `<mount>:` spec prefix,
# else this default. "secret" preserves prior (pre-parameterization) behavior.
default_mount="${OPENBAO_KV_MOUNT:-secret}"

# Fetch each mapping and export it. Format: [<mount>:]ENV_NAME=<kv-path>#<field>.
# Paths are given mount-relative (e.g. ai/llm, platform/acme).
for spec in "${specs[@]}"; do
  if [[ ! "$spec" =~ ^(([A-Za-z0-9_-]+):)?([A-Za-z_][A-Za-z0-9_]*)=([^#]+)#(.+)$ ]]; then
    die "bad --secret spec '$spec' (want [mount:]ENV=path#field)"
  fi
  mount="${BASH_REMATCH[2]:-$default_mount}"
  env_name="${BASH_REMATCH[3]}"
  kv_path="${BASH_REMATCH[4]}"
  field="${BASH_REMATCH[5]}"
  value="$(/usr/bin/curl -sSf --max-time 30 -H "X-Vault-Token: $token" \
      "$addr/v1/$mount/data/$kv_path" \
    | jq -re --arg f "$field" '.data.data[$f]')" \
    || die "read failed: $mount/$kv_path field '$field' (policy or path missing?)"
  export "$env_name=$value"
done

# The login token and AppRole bootstrap creds die with this shell; only the
# exported secret values (from the loop above) reach the exec'd child.
unset token "${env_prefix}_VAULT_ROLE_ID" "${env_prefix}_VAULT_SECRET_ID"

exec "$@"
