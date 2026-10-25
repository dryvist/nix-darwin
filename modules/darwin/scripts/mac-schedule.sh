# shellcheck shell=bash
# Guarded scheduled command. writeShellApplication supplies bash and strict mode.

log_decision() {
  "$MAC_SCHEDULE_LOGGER_BIN" -t mac-schedule "decision=$1"
}

if "$MAC_SCHEDULE_GATE_BIN" >/dev/null 2>&1; then
  gate_status=0
else
  gate_status=$?
fi

case "$gate_status" in
  0)
    ;;
  1)
    log_decision skip-clustered
    exit 0
    ;;
  3)
    log_decision stop-gate-3
    exit 3
    ;;
  *)
    log_decision "stop-gate-$gate_status"
    exit "$gate_status"
    ;;
esac

if ! battery_status="$("$MAC_SCHEDULE_PMSET_BIN" -g batt 2>/dev/null)" ||
  [[ "$battery_status" != *"AC Power"* ]]
then
  log_decision skip-battery
  exit 0
fi

models_url="${MAC_SCHEDULE_MODEL_ENDPOINT%/}/v1/models"
if ! model_list="$("$MAC_SCHEDULE_CURL_BIN" --fail --silent --show-error --max-time 15 "$models_url" 2>/dev/null)"; then
  log_decision skip-model-missing
  exit 0
fi

if ! printf '%s' "$model_list" |
  "$MAC_SCHEDULE_JQ_BIN" -e --arg model "$MAC_SCHEDULE_MODEL_ID" \
    '.data | if type == "array" then any(.[]; .id == $model) else false end' \
    >/dev/null 2>&1
then
  log_decision skip-model-missing
  exit 0
fi

log_decision run-command
exec "$@"
