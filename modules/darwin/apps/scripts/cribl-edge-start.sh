#!/usr/bin/env bash
# Cribl Edge startup script.
#
# Arguments (set by the Nix wrapper in cribl-edge.nix):
#   $1 = path to sops-rendered KEY=value secrets file (root-only 0400)
#   $2 = CRIBL_VOLUME_DIR (mutable state / data dir)
#   $3 = CRIBL_HOME (read-only path into the Nix store package)
#   $4 = Cribl fleet group name (default; overridden by the URL's `?group=` if present)
#
# Responsibilities:
#   1. Safely load credentials from the secrets file without shell eval.
#      Two formats are honored, in order of preference:
#        a) CRIBL_DIST_MASTER_URL=tls://TOKEN@HOST:PORT?group=GROUP
#           (the form Cribl Cloud's "Add Edge Node" panel displays today —
#            one var carries token, host, port, and group)
#        b) CRIBL_ORG_ID / CRIBL_WORKSPACE_ID / CRIBL_TOKEN (legacy 3-var flow)
#   2. Ensure the data + log directories exist.
#   3. On first start, enroll as a managed edge node and drop an .enrolled
#      marker so subsequent starts skip enrollment. Enrollment failures are
#      fatal — launchd retries via ThrottleInterval.
#   4. exec `cribl server`.

set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }

SECRETS_FILE="${1:?secrets file path required}"
CRIBL_VOLUME_DIR="${2:?volume dir required}"
CRIBL_HOME="${3:?cribl home required}"
CRIBL_GROUP="${4:?cribl fleet group required}"

export CRIBL_VOLUME_DIR CRIBL_HOME

if [ ! -r "$SECRETS_FILE" ]; then
  echo "$(ts) [ERROR] Cribl secrets file not readable: $SECRETS_FILE" >&2
  exit 1
fi

# Parse KEY=value without eval. Only whitelisted keys are honored; every other
# line is silently ignored so a malformed or tampered file cannot inject shell.
CRIBL_DIST_MASTER_URL=""
CRIBL_ORG_ID=""
CRIBL_WORKSPACE_ID=""
CRIBL_TOKEN=""
while IFS='=' read -r _key _value || [ -n "$_key" ]; do
  case "$_key" in
    ""|\#*) continue ;;
    CRIBL_DIST_MASTER_URL) CRIBL_DIST_MASTER_URL="$_value" ;;
    CRIBL_ORG_ID)          CRIBL_ORG_ID="$_value" ;;
    CRIBL_WORKSPACE_ID)    CRIBL_WORKSPACE_ID="$_value" ;;
    CRIBL_TOKEN)           CRIBL_TOKEN="$_value" ;;
  esac
done < "$SECRETS_FILE"
export CRIBL_DIST_MASTER_URL CRIBL_ORG_ID CRIBL_WORKSPACE_ID CRIBL_TOKEN

mkdir -p "$CRIBL_VOLUME_DIR" "$CRIBL_VOLUME_DIR/logs"

# Enroll once per data volume. The .enrolled marker guards idempotency so a
# hard failure (revoked token, network outage) surfaces via launchd rather
# than being silently swallowed.
if [ ! -f "$CRIBL_VOLUME_DIR/.enrolled" ] \
   && [ ! -f "$CRIBL_VOLUME_DIR/local/_system/instance.yml" ] \
   && [ ! -f "$CRIBL_VOLUME_DIR/local/edge/instance.yml" ]; then
  echo "$(ts) [INFO] Enrolling Cribl Edge to cloud..."

  # Derive enrollment args. Prefer CRIBL_DIST_MASTER_URL since Cribl Cloud's
  # "Add Edge Node" panel today displays the single-URL form by default. The
  # legacy `${WORKSPACE}-${ORG}.cribl.cloud:443` enrollment is a pre-2025
  # shape — Cribl Cloud has since moved worker-master comms to port 4200
  # with a different host name pattern, so the legacy path is left only as
  # a fallback for older secrets files.
  if [ -n "$CRIBL_DIST_MASTER_URL" ]; then
    # tls://TOKEN@HOST:PORT?group=GROUP — parse via bash parameter expansion,
    # not eval, to keep the no-shell-injection guarantee.
    _nopath="${CRIBL_DIST_MASTER_URL#*://}"
    _enroll_token="${_nopath%%@*}"
    _rest="${_nopath#*@}"
    _enroll_host="${_rest%%:*}"
    _portq="${_rest#*:}"
    _enroll_port="${_portq%%\?*}"
    if [[ "$_portq" == *"?group="* ]]; then
      _enroll_group="${_portq#*\?group=}"
      # Strip any trailing &key=val if Cribl adds more query params later.
      _enroll_group="${_enroll_group%%&*}"
    else
      _enroll_group="$CRIBL_GROUP"
    fi

    if [ -z "$_enroll_token" ] || [ -z "$_enroll_host" ] || [ -z "$_enroll_port" ] || [ -z "$_enroll_group" ]; then
      echo "$(ts) [ERROR] CRIBL_DIST_MASTER_URL is malformed (token/host/port/group): $CRIBL_DIST_MASTER_URL" >&2
      exit 1
    fi
  elif [ -n "$CRIBL_WORKSPACE_ID" ] && [ -n "$CRIBL_ORG_ID" ] && [ -n "$CRIBL_TOKEN" ]; then
    _enroll_token="$CRIBL_TOKEN"
    _enroll_host="${CRIBL_WORKSPACE_ID}-${CRIBL_ORG_ID}.cribl.cloud"
    _enroll_port="4200"
    _enroll_group="$CRIBL_GROUP"
  else
    echo "$(ts) [ERROR] No Cribl enrollment credentials in secrets file." >&2
    echo "$(ts) [ERROR] Set either CRIBL_DIST_MASTER_URL or all of CRIBL_ORG_ID, CRIBL_WORKSPACE_ID, CRIBL_TOKEN." >&2
    exit 1
  fi

  "$CRIBL_HOME/bin/cribl" mode-managed-edge \
    -H "$_enroll_host" \
    -p "$_enroll_port" \
    -u "$_enroll_token" \
    -g "$_enroll_group" \
    -S true

  : > "$CRIBL_VOLUME_DIR/.enrolled"
  echo "$(ts) [INFO] Cribl Edge enrolled to $_enroll_host:$_enroll_port (group=$_enroll_group)."
fi

exec "$CRIBL_HOME/bin/cribl" server
