# shellcheck shell=bash
# Run a command with a short-lived credential from OpenBao's Azure engine.
#
# OpenBao AppRole inputs come from the caller's environment. A role selects
# both the Azure engine role and the AppRole environment variable suffix.
# Fetched credentials stay in shell memory and Azure CLI's throwaway config.

set +x

prefix='[openbao-azure-creds]'

die() {
  printf '%s ERROR %s\n' "$prefix" "$*" >&2
  exit 1
}

warn() {
  printf '%s WARN %s\n' "$prefix" "$*" >&2
}

if [[ "$#" -lt 2 ]]; then
  die 'usage: openbao-azure-creds <role> <command> [args...]'
fi

role="$1"
shift
case "$role" in
  ''|.|..|*/*|*[![:alnum:]_-]*)
    die 'role must contain only letters, numbers, underscores, or hyphens'
    ;;
esac

if [[ -z "${BAO_ADDR:-}${VAULT_ADDR:-}" ]]; then
  die 'BAO_ADDR or VAULT_ADDR is required'
fi

tenant_id="${OPENBAO_AZURE_TENANT_ID:-}"
[[ -n "$tenant_id" ]] || die 'OPENBAO_AZURE_TENANT_ID is required'

role_env="$(printf '%s' "$role" | tr '[:lower:]-' '[:upper:]_')"
role_id_env="OPENBAO_APPROLE_AZURE_${role_env}_ROLE_ID"
secret_id_env="OPENBAO_APPROLE_AZURE_${role_env}_SECRET_ID"
role_id="$(printenv "$role_id_env" 2>/dev/null || true)"
[[ -n "$role_id" ]] || die "$role_id_env is required"

wrapped_secret_id="${OPENBAO_AZURE_WRAPPED_SECRET_ID:-}"
if [[ -n "$wrapped_secret_id" ]]; then
  secret_id="$(BAO_TOKEN="$wrapped_secret_id" bao unwrap -format=json | jq -er '.data.secret_id')" \
    || die 'could not unwrap the AppRole secret ID'
else
  secret_id="$(printenv "$secret_id_env" 2>/dev/null || true)"
  [[ -n "$secret_id" ]] || die "$secret_id_env or OPENBAO_AZURE_WRAPPED_SECRET_ID is required"
fi
unset wrapped_secret_id

login_json="$(printf '%s\0%s' "$role_id" "$secret_id" \
  | jq -Rs 'split("\u0000") | {role_id: .[0], secret_id: .[1]}')" \
  || die 'could not prepare the AppRole login request'
login_response="$(printf '%s' "$login_json" \
  | env -u BAO_TOKEN -u VAULT_TOKEN bao write -format=json auth/approle/login -)" \
  || die 'OpenBao AppRole login failed'
openbao_token="$(jq -er '.auth.client_token' <<<"$login_response")" \
  || die 'OpenBao AppRole login returned no token'
unset login_json login_response role_id secret_id

creds_json="$(BAO_TOKEN="$openbao_token" bao read -format=json "azure/creds/$role")" \
  || die 'OpenBao Azure credential read failed'
client_id="$(jq -er '.data.client_id' <<<"$creds_json")" \
  || die 'OpenBao Azure credential response has no client_id'
client_secret="$(jq -er '.data.client_secret' <<<"$creds_json")" \
  || die 'OpenBao Azure credential response has no client_secret'
unset creds_json openbao_token

unset "$role_id_env" "$secret_id_env" OPENBAO_AZURE_WRAPPED_SECRET_ID \
  OPENBAO_AZURE_TENANT_ID BAO_TOKEN VAULT_TOKEN AZURE_DEVOPS_EXT_PAT

umask 077
AZURE_CONFIG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openbao-azure.XXXXXX")" \
  || die 'could not create the Azure CLI config path'
export AZURE_CONFIG_DIR

cleanup() {
  local exit_status="$?"
  local cleanup_failed=0

  if ! az logout >/dev/null 2>&1; then
    warn 'az logout failed'
  fi
  if ! rm -rf -- "$AZURE_CONFIG_DIR"; then
    warn 'could not remove the Azure CLI config path'
    cleanup_failed=1
  fi
  if [[ "$exit_status" -eq 0 && "$cleanup_failed" -ne 0 ]]; then
    exit_status=1
  fi
  exit "$exit_status"
}
trap cleanup EXIT

unset role_env role_id_env secret_id_env

login_attempt=1
max_attempts=7
while (( login_attempt <= max_attempts )); do
  if az login --service-principal -u "$client_id" -p "$client_secret" \
    --tenant "$tenant_id" --allow-no-subscriptions >/dev/null 2>&1; then
    break
  fi
  if (( login_attempt == max_attempts )); then
    die "Azure login failed after $max_attempts attempts"
  fi
  warn "Azure login failed (attempt $login_attempt/$max_attempts); retrying in 10 seconds"
  sleep 10
  ((login_attempt += 1))
done

unset client_id client_secret tenant_id role

# A top-level exec would skip the EXIT cleanup trap. The subshell execs the
# requested command while this shell stays alive to log out and remove config.
(
  exec "$@"
)
