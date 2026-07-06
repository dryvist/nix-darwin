#!/bin/bash

set -u

if [ "$#" -ne 8 ]; then
  echo "usage: $0 <flake> <host-name> <target-weekday> <target-hour> <target-minute> <state-dir> <log-tag> <darwin-rebuild>" >&2
  exit 64
fi

flake="$1"
host_name="$2"
target_weekday="$3"
target_hour="$4"
target_minute="$5"
state_dir="$6"
log_tag="$7"
darwin_rebuild="$8"

state_file="${state_dir}/last-attempted-target-day"
lock_dir="/var/run/nix-darwin-auto-upgrade.lock"

log() {
  message="$1"
  printf '%s %s\n' "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" "$message"
  /usr/bin/logger -t "${log_tag}" "${message}"
}

if ! /bin/mkdir "${lock_dir}" 2>/dev/null; then
  log "skip: another auto-upgrade run is active"
  exit 0
fi
trap '/bin/rmdir "${lock_dir}" 2>/dev/null || true' EXIT

if ! /usr/bin/install -d -o root -g wheel -m 0755 "${state_dir}"; then
  log "failure: could not create state directory ${state_dir}"
  exit 1
fi

epoch="$("/bin/date" -u '+%s')"
utc_day=$((epoch / 86400))
utc_seconds_of_day=$((epoch % 86400))
# 1970-01-01 was a Thursday. ISO-style weekdays: Monday=1, Friday=5, Sunday=7.
utc_weekday=$((((utc_day + 3) % 7) + 1))
target_seconds_of_day=$(((target_hour * 3600) + (target_minute * 60)))

diff=$((utc_weekday - target_weekday))
if [ "${diff}" -lt 0 ]; then
  days_ago=$((diff + 7))
elif [ "${diff}" -eq 0 ] && [ "${utc_seconds_of_day}" -lt "${target_seconds_of_day}" ]; then
  days_ago=7
else
  days_ago="${diff}"
fi

target_day=$((utc_day - days_ago))
last_attempted=""
if [ -r "${state_file}" ]; then
  last_attempted="$(/bin/cat "${state_file}")"
fi

if [ "${last_attempted}" = "${target_day}" ]; then
  log "skip: target day ${target_day} was already attempted"
  exit 0
fi

tmp_state="${state_file}.$$"
if ! printf '%s\n' "${target_day}" > "${tmp_state}" || ! /bin/mv "${tmp_state}" "${state_file}"; then
  /bin/rm -f "${tmp_state}"
  log "failure: could not record target day ${target_day}"
  exit 1
fi

log "start: darwin-rebuild switch --flake ${flake}#${host_name}"
"${darwin_rebuild}" switch \
  --flake "${flake}#${host_name}" \
  --refresh \
  --no-write-lock-file \
  --print-build-logs
status="$?"

if [ "${status}" -eq 0 ]; then
  log "success: auto-upgrade completed for ${host_name}"
else
  log "failure: auto-upgrade exited ${status} for ${host_name}"
fi

exit "${status}"
