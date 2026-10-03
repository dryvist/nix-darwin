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
#   openbao-run [--domain local-llm] \
#     [--env-file <0600-path>] \
#     [--secret [<mount>:]ENV_NAME=<kv-path>#<field>] \
#     [--secrets [<mount>:]<kv-path>] \
#     -- <command> [args...]
#
# --secret injects ONE field under a chosen name. --secrets injects EVERY key
# at a KV v2 document under its own key name — the shape needed to replace a
# `doppler run --` that fed a tool a whole config. Both may be repeated and
# mixed; they are applied strictly left to right, so a later flag overrides an
# earlier one and documents layer (base first, overrides last).
#
# Authentication: with --domain, this domain's AppRole is REQUIRED and its
# absence is fatal — unattended agents must never silently fall through to
# something ambient. Without --domain, an already-valid BAO_TOKEN/VAULT_TOKEN
# in the environment is used, which is the interactive workstation path.
#
# Login backoff (per-domain circuit breaker): a refused AppRole login must never
# be retried faster than a backoff allows, whatever restarts this wrapper (a
# launchd KeepAlive or StartInterval re-runs it, and a refusal streak can lock
# the whole role out). A refusal is an HTTP 400, 401 or 403 from the login
# endpoint; timeouts, connection errors and 5xx are network faults, neither
# counted nor delayed. Each domain keeps one state file:
#
#   ${XDG_STATE_HOME:-$HOME/.local/state}/openbao-run/<domain>
#
# directory 0700, file 0600, holding "<consecutive refusals> <epoch seconds
# before which no login may be attempted>" and never a credential. The Nth
# consecutive refusal blocks login for min(60 * 2^(N-1), 900) seconds: 60, 120,
# 240, 480, then 900. While blocked the wrapper contacts nothing and exits 75
# (EX_TEMPFAIL). A successful login deletes the file; deleting it by hand also
# resets the breaker.
#
# Each --secret/--secrets reads from the KV v2 mount named by the optional leading
# `<mount>:` prefix, defaulting to $OPENBAO_KV_MOUNT (itself defaulting to
# "secret" for backward compat) when the prefix is omitted. This lets one
# invocation mix mounts (see the second --secret in the example below).
#
# Example:
#   openbao-run --domain example \
#     --secret API_TOKEN=app/example#token \
#     --secret other-mount:DNS_KEY=dns/example#key \
#     -- some-command --flag
#
# `pkgs.writeShellApplication` wraps this in `set -euo pipefail` and lints it,
# so this file omits its own `set` boilerplate.

prefix="[openbao-run]"

# Always the Apple platform binary in production — see the Local Network
# privacy note below. Overridable ONLY so the shell tests can stub OpenBao.
curl_bin="${OPENBAO_RUN_CURL_BIN:-/usr/bin/curl}"
die() {
  echo "$prefix ERROR $*" >&2
  exit 1
}

domain=""
env_file=""
# One ordered list so --secret and --secrets apply in the order given (later
# wins). Each entry is "field\t<spec>" or "doc\t<spec>".
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
      specs+=("field	${2:?--secret needs ENV=path#field}")
      shift 2
      ;;
    --secrets)
      specs+=("doc	${2:?--secrets needs a kv path}")
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *) die "unknown argument: $1 (expected --domain, --env-file, --secret, --secrets, or --)" ;;
  esac
done

[ "${#specs[@]}" -gt 0 ] || die "no --secret or --secrets mappings given"
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
#
# BASH 3.2 ONLY. Apple ships bash 3.2 and launchd jobs here are launched
# through /bin/bash on purpose (see the launchd-interpreter convention), so
# this file must parse AND run under it. `${domain^^}` is bash 4+ and fails
# at runtime with `bad substitution` under 3.2 — it still passes `bash -n`,
# so a syntax check alone will not catch a regression here. Use tr.
env_prefix=""
role_id=""
secret_id=""
ambient_token=""
if [ -n "$domain" ]; then
  env_prefix="$(printf '%s' "$domain" | tr '[:lower:]-' '[:upper:]_')"
  role_id="$(resolve "${env_prefix}_VAULT_ROLE_ID")"
  secret_id="$(resolve "${env_prefix}_VAULT_SECRET_ID")"
  # A domain names an AppRole, so its absence is FATAL rather than a fall
  # through to whatever token happens to be ambient — an unattended agent that
  # silently borrowed an interactive credential would be worse than a failure.
  [ -n "$role_id" ] || die "${env_prefix}_VAULT_ROLE_ID not in $src"
  [ -n "$secret_id" ] || die "${env_prefix}_VAULT_SECRET_ID not in $src"
else
  # Interactive workstation path: no AppRole named, so use the token the
  # caller already holds from a native login.
  ambient_token="$(resolve BAO_TOKEN)"
  [ -n "$ambient_token" ] || ambient_token="$(resolve VAULT_TOKEN)"
  [ -n "$ambient_token" ] || die "no --domain given and no BAO_TOKEN/VAULT_TOKEN in $src — authenticate to OpenBao first"
fi

# ALL OpenBao HTTP goes through /usr/bin/curl — the APPLE PLATFORM binary,
# hardcoded path, never a nixpkgs curl. macOS Local Network privacy silently
# denies LAN access in GUI-session launchd contexts ("connect: no route to
# host"). Verified live 2026-07-17 on macOS 26.5.2 from a gui/501 one-shot: the
# nix-store `bao` CLI got EHOSTUNREACH where /usr/bin/curl completed with HTTP
# 200 (ssh sessions are exempt, which is why shell tests never reproduced it).
# There is no supported CLI/MDM pre-approval for Local Network TCC.
#
# USING THE PLATFORM BINARY IS NECESSARY BUT NOT SUFFICIENT — do not read the
# paragraph above as "TCC cannot be the cause here". Disproved live 2026-07-28
# on jevans-ms: this very invocation got `Immediate connect fail ... No route to
# host` from /usr/bin/curl, deterministically, 3/3 rounds, while a bare
# /usr/bin/curl to the SAME host in the SAME launchd process returned 200 and
# the same login run over ssh exited 0. The denial follows the responsible app,
# not the executed binary, so one path can be permitted while another is not.
# Only System Settings -> Privacy & Security -> Local Network clears it.
#
# jq (no network) parses the responses.

# AppRole login -> a short-lived token, used only for the reads below. Never
# persisted; scoped to this process. Credentials travel via a private
# temporary payload on stdin (never argv).
login_payload=""
[ -n "$role_id" ] && login_payload="$(jq -n --arg r "$role_id" --arg s "$secret_id" \
  '{role_id: $r, secret_id: $s}')"
# Why a diagnostic at all: `curl -sSf` renders a refused connection as the
# generic "Couldn't connect to server", which reads as a dead service and sent a
# 2026-07-28 investigation down three wrong paths before `-v` revealed the
# actual errno. The re-probe below costs one request on the failure path only,
# carries NO credentials (plain GET of the unauthenticated health endpoint), and
# turns a 40-minute hunt into one line. Connect-level failures are
# credential-independent, so health is a faithful stand-in for the login socket.
login_diagnosis() {
  local detail
  detail="$("$curl_bin" -sv --max-time 10 -o /dev/null "$addr/v1/sys/health" 2>&1 || true)"
  case "$detail" in
    *'No route to host'*)
      echo "$prefix HINT: EHOSTUNREACH to $addr from this context." >&2
      echo "$prefix       This is macOS Local Network privacy (TCC) denying the agent, NOT a network fault." >&2
      echo "$prefix       Using /usr/bin/curl does not exempt it — the denial follows the responsible app." >&2
      echo "$prefix       Fix: System Settings -> Privacy & Security -> Local Network, enable this agent." >&2
      echo "$prefix       Confirm: the same command run over ssh will succeed; ssh sessions are exempt." >&2
      ;;
  esac
}

# Login backoff state (see the header): "<refusals> <next-allowed epoch>".
# State is written only after a refusal, so a failed write is logged rather than
# fatal — the login failure that follows is the exit the caller needs to see.
refusals=0
record_refusal() { # $1 HTTP status
  local doublings delay
  refusals=$((refusals + 1))
  doublings=$((refusals - 1))
  [ "$doublings" -le 4 ] || doublings=4
  delay=$((60 << doublings))
  [ "$delay" -le 900 ] || delay=900
  if ! { mkdir -p "$state_dir" && chmod 0700 "$state_dir" \
    && (umask 077 && printf '%s %s\n' "$refusals" "$(($(date +%s) + delay))" > "$state_file"); }; then
    echo "$prefix WARN could not record the login backoff in $state_file" >&2
  fi
  echo "$prefix login refused (HTTP $1) for domain '$domain': refusal $refusals, no login for the next $delay seconds" >&2
}

if [ -n "$login_payload" ]; then
  state_dir="${XDG_STATE_HOME:-${HOME:?HOME is not set}/.local/state}/openbao-run"
  state_file="$state_dir/$domain"
  if [ -f "$state_file" ]; then
    saved_refusals=""
    saved_next=""
    read -r saved_refusals saved_next < "$state_file" || true
    case "$saved_refusals:$saved_next" in
      *[!0-9:]* | :* | *:)
        echo "$prefix login backoff state for domain '$domain' is unreadable ($state_file); ignoring it" >&2
        ;;
      *)
        refusals=$((10#$saved_refusals))
        remaining=$((10#$saved_next - $(date +%s)))
        if [ "$remaining" -gt 0 ]; then
          echo "$prefix circuit open for domain '$domain': no login for $remaining more seconds" >&2
          exit 75
        fi
        ;;
    esac
  fi

  # -f makes an HTTP error status exit 22; -w still appends the status, which is
  # how a refusal (credential rejected) is told apart from a network fault.
  login_rc=0
  login_resp="$(printf '%s' "$login_payload" \
    | "$curl_bin" -sSf --max-time 30 -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
        --data-binary @- "$addr/v1/auth/approle/login")" || login_rc=$?
  login_code="${login_resp: -3}"
  if [ "$login_rc" -eq 0 ] && token="$(printf '%s' "${login_resp%???}" | jq -re '.auth.client_token')"; then
    if [ -e "$state_file" ]; then
      rm -f "$state_file"
      echo "$prefix circuit reset for domain '$domain': login succeeded" >&2
    fi
  else
    case "$login_code" in
      400 | 401 | 403) record_refusal "$login_code" ;;
      *) login_diagnosis ;;
    esac
    die "AppRole login failed for domain '$domain' at $addr"
  fi
  unset login_resp
else
  token="$ambient_token"
fi

# KV v2 mount, per-secret override via an optional `<mount>:` spec prefix,
# else this default. "secret" preserves prior (pre-parameterization) behavior.
default_mount="${OPENBAO_KV_MOUNT:-secret}"

# Read one KV v2 document, whole. Leaves the JSON in $doc_json rather than
# printing it, so no secret ever reaches a command substitution's pipe buffer.
doc_json=""
read_doc() { # $1 mount, $2 path
  doc_json="$("$curl_bin" -sSf --max-time 30 -H "X-Vault-Token: $token" \
    "$addr/v1/$1/data/$2")" \
    || die "read failed: $1/$2 (path missing, or the credential lacks read on it?)"
}

# Apply each mapping in the order given, so a later flag overrides an earlier
# one and documents layer. Field form: [<mount>:]ENV_NAME=<kv-path>#<field>.
# Document form: [<mount>:]<kv-path>. Paths are mount-relative (e.g. ai/llm).
for spec in "${specs[@]}"; do
  kind="${spec%%	*}"
  spec="${spec#*	}"
  if [ "$kind" = "field" ]; then
    if [[ ! "$spec" =~ ^(([A-Za-z0-9_-]+):)?([A-Za-z_][A-Za-z0-9_]*)=([^#]+)#(.+)$ ]]; then
      die "bad --secret spec '$spec' (want [mount:]ENV=path#field)"
    fi
    mount="${BASH_REMATCH[2]:-$default_mount}"
    env_name="${BASH_REMATCH[3]}"
    kv_path="${BASH_REMATCH[4]}"
    field="${BASH_REMATCH[5]}"
    read_doc "$mount" "$kv_path"
    value="$(printf '%s' "$doc_json" | jq -re --arg f "$field" '.data.data[$f]')" \
      || die "read failed: $mount/$kv_path field '$field' (field missing at that path?)"
    export "$env_name=$value"
  else
    if [[ ! "$spec" =~ ^(([A-Za-z0-9_-]+):)?([^#]+)$ ]]; then
      die "bad --secrets spec '$spec' (want [mount:]path)"
    fi
    mount="${BASH_REMATCH[2]:-$default_mount}"
    kv_path="${BASH_REMATCH[3]}"
    read_doc "$mount" "$kv_path"
    # A document that exports nothing is the failure this wrapper exists to
    # make loud: exiting 0 with an unset environment looks like success to the
    # child, which then fails somewhere far less obvious.
    [ "$(printf '%s' "$doc_json" | jq -r '.data.data | length')" -gt 0 ] \
      || die "no keys at $mount/$kv_path — nothing to export"
    # Keys become variable names, so anything that is not an identifier is
    # rejected here rather than smuggled into the export below.
    bad_keys="$(printf '%s' "$doc_json" \
      | jq -r '.data.data | keys[] | select(test("^[A-Za-z_][A-Za-z0-9_]*$") | not)' \
      | tr '\n' ' ')"
    [ -z "${bad_keys// /}" ] \
      || die "key(s) at $mount/$kv_path are not valid environment variable names: ${bad_keys% }"
    # One eval of jq's @sh-quoted output: injection-safe, and values containing
    # newlines survive intact where a line-by-line read would split them.
    eval "$(printf '%s' "$doc_json" \
      | jq -r '.data.data | to_entries[] | "export \(.key)=\(.value | tostring | @sh)"')"
  fi
done
unset doc_json

# The login token and AppRole bootstrap creds die with this shell; only the
# exported secret values (from the loop above) reach the exec'd child.
unset token ambient_token
[ -n "$env_prefix" ] && unset "${env_prefix}_VAULT_ROLE_ID" "${env_prefix}_VAULT_SECRET_ID"

exec "$@"
