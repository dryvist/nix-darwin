set -euo pipefail
: "${mas:?}" "${sudo:?}" "${brew:?}" "${notifier:?}" "${workstation:?}"
umask 077

state="$HOME/Library/Application Support/app-updates"
logs="$HOME/Library/Logs/app-updates"
mkdir -p "$state" "$logs"
now=$(date +%s)
read_number() {
  local value=0
  if [[ -f "$1" ]]; then read -r value < "$1" || true; fi
  [[ "$value" =~ ^[0-9]+$ ]] || value=0
  printf '%s\n' "$value"
}
write_number() {
  printf '%s\n' "$2" > "$1.tmp"
  mv "$1.tmp" "$1"
}

kind=$1
[[ "$kind" == mas || "$kind" == brew || "$kind" == health ]] || exit 64
exec 9> "$state/$kind.lock"
/usr/bin/lockf -s -t 0 9 || exit 0
if [[ "$kind" == health ]]; then
  exec >> "$logs/health.log" 2>&1
  for app in brew mas; do
    [[ "$app" != mas || "$workstation" == 1 ]] || continue
    exec 8> "$state/$app.lock"
    /usr/bin/lockf -s -t 0 8 || continue
    limit=691200
    [[ "$app" != mas ]] || limit=172800
    success=$(read_number "$state/$app.success")
    baseline=$success
    [[ "$baseline" != 0 ]] || baseline=$(read_number "$state/activated")
    reason=''
    if (( baseline > 0 && now - baseline > limit )); then reason='has not completed successfully on schedule'; fi
    if [[ "$app" == mas ]] && (( $(read_number "$state/mas.pending-days") >= 2 )); then reason='still detects available updates'; fi
    if (( $(read_number "$state/$app.exit") != 0 )); then reason='failed during its latest attempt'; fi
    if [[ -z "$reason" ]]; then
      rm -f "$state/$app.notified"
    elif (( now - $(read_number "$state/$app.notified") >= 86400 )); then
      if "$notifier" - "$app updater $reason. See $logs/$app.log" <<'APPLESCRIPT'
on run argv
  display notification (item 1 of argv) with title "App updates need attention"
end run
APPLESCRIPT
      then
        write_number "$state/$app.notified" "$now"
      else
        printf '%s notification delivery failed for %s\n' "$now" "$app"
      fi
    fi
  done
  exit 0
fi

exec >> "$logs/$kind.log" 2>&1
write_number "$state/$kind.attempt" "$now"
write_number "$state/$kind.exit" 125
printf '%s starting %s update\n' "$now" "$kind"
status=0
if [[ "$kind" == brew ]]; then
  timeout --kill-after=10s 3590s "$brew" upgrade --greedy || status=$?
else
  timeout --kill-after=1s 19s "$mas" list > "$logs/mas.before" || status=$?
  if (( status == 0 )); then
    # sudoers enforces the privileged timeout; a user-owned timer cannot kill root.
    "$sudo" -n "$mas" update --inaccurate --check-min-os || status=$?
  fi
  timeout --kill-after=1s 19s "$mas" list > "$logs/mas.after" || status=$?
  if timeout --kill-after=1s 19s "$mas" outdated --inaccurate --check-min-os > "$logs/mas.remaining"; then
    # Count separate local dates, never repeated login/manual runs on one day.
    day=$(date +%Y%m%d)
    yesterday=$(date -d yesterday +%Y%m%d)
    last_day=$(read_number "$state/mas.pending-date")
    if [[ ! -s "$logs/mas.remaining" ]]; then
      write_number "$state/mas.pending-days" 0
      rm -f "$state/mas.pending-date"
    elif [[ "$last_day" != "$day" ]]; then
      days=1
      if [[ "$last_day" == "$yesterday" ]]; then days=$(( $(read_number "$state/mas.pending-days") + 1 )); fi
      write_number "$state/mas.pending-days" "$days"
      write_number "$state/mas.pending-date" "$day"
    fi
  else
    status=$?
  fi
fi
write_number "$state/$kind.exit" "$status"
if (( status == 0 )); then write_number "$state/$kind.success" "$(date +%s)"; fi
printf '%s completed %s update: exit %s\n' "$(date +%s)" "$kind" "$status"
exit "$status"
