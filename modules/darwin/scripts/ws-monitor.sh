#!/bin/bash
# Measure loop lateness and sample system state every 15 seconds.

set -euo pipefail

LOG_DIR="/var/log/ws-monitor"
LOG_FILE="${LOG_DIR}/ws-monitor.jsonl"
CAPTURE_DIR="${LOG_DIR}/captures"
CAPTURE_STATE_FILE="${LOG_DIR}/.last-capture-epoch"

/bin/mkdir -p "$LOG_DIR" "$CAPTURE_DIR"

rotate_log() {
  local log_size
  log_size=$(/usr/bin/stat -f%z "$LOG_FILE" 2>/dev/null || printf '0')
  case "$log_size" in
    ''|*[!0-9]*) log_size=0 ;;
  esac

  if (( log_size > 52428800 )); then
    /bin/mv "$LOG_FILE" "$LOG_FILE.$(/bin/date -u '+%Y%m%dT%H%M%SZ').bak"
  fi
}

emit_event() {
  local ts="$1"
  local severity="$2"
  local gap_s="$3"
  local io_pending_s="$4"
  local memory_free_pct
  local swap_used_mb
  local wired_pages
  local windowserver_footprint=''
  local windowserver_pid
  local top_processes
  local data_volume_free_gb

  memory_free_pct=$(
    /usr/bin/memory_pressure 2>/dev/null |
      /usr/bin/awk -F ':' '/free percentage/ { gsub(/[^0-9]/, "", $NF); print $NF; exit }'
  ) || memory_free_pct=''

  swap_used_mb=$(
    /usr/sbin/sysctl -n vm.swapusage 2>/dev/null |
      /usr/bin/awk '{
        for (i = 1; i <= NF; i++) {
          if ($i == "used" && i + 2 <= NF) {
            value = $(i + 2)
            unit = substr(value, length(value), 1)
            sub(/[KMG]$/, "", value)
            if (unit == "G") value *= 1024
            else if (unit == "K") value /= 1024
            printf "%.2f", value
            exit
          }
        }
      }'
  ) || swap_used_mb=''

  wired_pages=$(
    /usr/bin/vm_stat 2>/dev/null |
      /usr/bin/awk -F: '/Pages wired down/ { gsub(/[^0-9]/, "", $2); print $2; exit }'
  ) || wired_pages=''

  windowserver_pid=$(/usr/bin/pgrep -x WindowServer 2>/dev/null | /usr/bin/head -n 1 || true)
  if [ -n "$windowserver_pid" ]; then
    windowserver_footprint=$(
      /usr/bin/footprint -p "$windowserver_pid" 2>/dev/null |
        /usr/bin/awk -F: '/phys_footprint/ { sub(/^[[:space:]]*/, "", $2); print $2; exit }'
    ) || windowserver_footprint=''
  fi

  # awk reads all of ps output; head would close the pipe and fail the pipeline under pipefail.
  top_processes=$(
    /bin/ps -Ao pid,%cpu,rss,comm -r |
      /usr/bin/awk 'NR > 1 && NR <= 6' |
      jq -Rsc 'split("\n") | map(select(length > 0))'
  ) || top_processes='[]'

  data_volume_free_gb=$(
    /bin/df -g /System/Volumes/Data 2>/dev/null |
      /usr/bin/awk 'END { if (NF >= 4) print $4 }'
  ) || data_volume_free_gb=''

  rotate_log
  jq -nc \
    --arg ts "$ts" \
    --arg severity "$severity" \
    --argjson gap_s "$gap_s" \
    --argjson io_pending_s "$io_pending_s" \
    --arg memory_free_pct "$memory_free_pct" \
    --arg swap_used_mb "$swap_used_mb" \
    --arg wired_pages "$wired_pages" \
    --arg windowserver_footprint "$windowserver_footprint" \
    --argjson top_processes "$top_processes" \
    --arg data_volume_free_gb "$data_volume_free_gb" \
    '{
      ts: $ts,
      severity: $severity,
      gap_s: $gap_s,
      io_probe_pending_s: $io_pending_s,
      memory_free_pct: (($memory_free_pct | tonumber?) // null),
      swap_used_mb: (($swap_used_mb | tonumber?) // null),
      wired_pages: (($wired_pages | tonumber?) // null),
      windowserver_footprint: (if $windowserver_footprint == "" then null else $windowserver_footprint end),
      top_processes: $top_processes,
      data_volume_free_gb: (($data_volume_free_gb | tonumber?) // null)
    }' >> "$LOG_FILE"
}

prune_captures() {
  local -a capture_files=()
  local capture_count
  local stale_count
  local index
  local stale_capture

  shopt -s nullglob
  capture_files=( "$CAPTURE_DIR"/*.tailspin )
  shopt -u nullglob

  capture_count=${#capture_files[@]}
  (( capture_count > 20 )) || return 0
  stale_count=$((capture_count - 20))

  for (( index = 0; index < stale_count; index++ )); do
    stale_capture=${capture_files[$index]}
    /bin/rm -f "$stale_capture" "${stale_capture%.tailspin}.txt" "${stale_capture%.tailspin}.summary.txt"
  done
}

# tailspin keeps about 20 s of history, so this must run while the stall is
# in progress. The summary (not the full spindump) is what Cribl ships.
capture_stall() {
  local capture_stamp="$1"
  local tailspin_file="${CAPTURE_DIR}/${capture_stamp}.tailspin"
  local spindump_file="${CAPTURE_DIR}/${capture_stamp}.txt"
  local summary_file="${CAPTURE_DIR}/${capture_stamp}.summary.txt"

  (
    /usr/bin/tailspin save -r ws-monitor-stall "$tailspin_file" || exit 1
    /usr/sbin/spindump -i "$tailspin_file" -o "$spindump_file" || true
    if [ -r "$spindump_file" ]; then
      {
        /usr/bin/head -n 80 "$spindump_file"
        /usr/bin/grep -E '^Process:|blocked by' "$spindump_file" | /usr/bin/head -n 600
      } > "$summary_file" || true
    fi
    prune_captures
  ) &
}

last_capture_epoch=0
if [ -r "$CAPTURE_STATE_FILE" ]; then
  IFS= read -r last_capture_epoch < "$CAPTURE_STATE_FILE" || true
fi
case "$last_capture_epoch" in
  ''|*[!0-9]*) last_capture_epoch=0 ;;
esac

# Metadata write + rename on the log volume, run in the background: a blocked
# APFS shows up as a probe still in flight while this loop keeps ticking.
start_probe() {
  ( /bin/echo "$1" > "${PROBE_FILE}.tmp" && /bin/mv -f "${PROBE_FILE}.tmp" "$PROBE_FILE" ) &
  probe_pid=$!
  probe_started=$1
}

# shortcut: detects stalls that block APFS metadata I/O or the whole machine; a WindowServer-only hang (no I/O) is left to the OS watchdog report and the unified-log input.
PROBE_FILE="${LOG_DIR}/.io-probe"
probe_pid=0
probe_started=0
previous_tick=$(/bin/date '+%s')
ticks_since_log=0

while true; do
  /bin/sleep 5
  now_tick=$(/bin/date '+%s')
  gap_s=$((now_tick - previous_tick))
  (( gap_s >= 0 )) || gap_s=0
  previous_tick=$now_tick

  io_pending_s=0
  if (( probe_pid > 0 )) && kill -0 "$probe_pid" 2>/dev/null; then
    io_pending_s=$((now_tick - probe_started))
  else
    start_probe "$now_tick"
  fi

  severity=normal
  if (( gap_s > 15 || io_pending_s > 8 )); then
    severity=FREEZE
  fi

  # Capture first: later steps (event write) can block on the stall itself.
  if [ "$severity" = "FREEZE" ] && (( now_tick - last_capture_epoch >= 600 )); then
    last_capture_epoch=$now_tick
    capture_stamp=$(/bin/date -u '+%Y%m%dT%H%M%SZ')
    capture_stall "$capture_stamp"
    /usr/bin/printf '%s\n' "$last_capture_epoch" > "$CAPTURE_STATE_FILE"
  fi

  ticks_since_log=$((ticks_since_log + 1))
  if (( ticks_since_log >= 3 )) || [ "$severity" = "FREEZE" ]; then
    ts=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')
    emit_event "$ts" "$severity" "$gap_s" "$io_pending_s"
    ticks_since_log=0
  fi
done
