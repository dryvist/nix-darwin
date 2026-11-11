# shellcheck shell=bash
# Hold-file parsing shared by comin-confirmer and comin-hold; the module prepends this file to both.
#
# Format: key=value lines by=, why=, set=, until=, times as UTC YYYY-MM-DDTHH:MM:SSZ. Blank lines and
# lines starting with # are skipped and unknown keys are ignored; any other line that is not key=value
# makes the hold malformed. Valid means all four keys present and non-empty, none repeated, both times
# well formed, until after set, and until at most 12 hours after set and after now. Only the first
# 4096 bytes are read, so a larger hand-edited file is judged on its truncated text and usually reads
# as malformed, that is absent. The file is read as data only, never sourced.
#
# Callers set hold_file and now (epoch seconds). `date` must be GNU coreutils date (`date -d`).

hold_max=43200

# Values are input: control characters, NEL and the Unicode line and paragraph separators are
# stripped, `=` becomes `:` so a value cannot forge a `key=value` token in a log line, and the length
# is capped.
clean() {
  local value
  value="$(printf '%s' "$1" | tr -d '\000-\037\177')"
  value="${value//$'\xc2\x85'/}"
  value="${value//$'\xe2\x80\xa8'/}"
  value="${value//$'\xe2\x80\xa9'/}"
  printf '%s' "${value//=/:}" | cut -c1-200
}

# Sets hold_state to absent, unreadable, malformed, expired or held; hold_reason for malformed; and
# hold_by, hold_why, hold_until for expired and held.
read_hold() {
  hold_state=absent hold_reason="" hold_by="" hold_why="" hold_until=""
  [ -e "$hold_file" ] || return 0
  local text line key value by="" why="" set="" until="" seen=" " set_s until_s
  if [ ! -f "$hold_file" ] || ! text="$(head -c 4096 "$hold_file" 2> /dev/null)"; then
    hold_state=unreadable
    return 0
  fi
  hold_state=malformed
  while IFS= read -r line; do
    case "$line" in
      "" | "#"*) continue ;;
    esac
    if [[ ! $line =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      hold_reason="line without key=value"
      return 0
    fi
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      by | why | set | until) ;;
      *) continue ;;
    esac
    if [[ $seen == *" $key "* ]]; then
      hold_reason="duplicate $key"
      return 0
    fi
    seen+="$key "
    printf -v "$key" '%s' "$(clean "$value")"
  done <<< "$text"
  for key in by why set until; do
    if [ -z "${!key}" ]; then
      hold_reason="missing $key"
      return 0
    fi
  done
  for key in set until; do
    if [[ ! ${!key} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
      || ! date -u -d "${!key}" +%s > /dev/null 2>&1; then
      hold_reason="bad $key time"
      return 0
    fi
  done
  set_s="$(date -u -d "$set" +%s)"
  until_s="$(date -u -d "$until" +%s)"
  if [ "$until_s" -le "$set_s" ]; then
    hold_reason="until is not after set"
    return 0
  fi
  if [ $((until_s - set_s)) -gt "$hold_max" ] || [ $((until_s - now)) -gt "$hold_max" ]; then
    hold_reason="longer than 12 hours"
    return 0
  fi
  hold_by="$by" hold_why="$why" hold_until="$until"
  if [ "$now" -ge "$until_s" ]; then
    hold_state=expired
  else
    hold_state=held
  fi
}
