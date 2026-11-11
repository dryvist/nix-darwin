# shellcheck shell=bash
# Set, show or clear the comin confirmer hold (see ./comin-confirmer.sh).
#
#   comin-hold set --by <who> --why <text> --for <N>h|<N>m   (at most 12h)
#   comin-hold show
#   comin-hold clear
#
# The hold file is root-owned (mode 0644), so set and clear need root. Values are stored on one line
# each with control characters stripped and length capped.
#
# Environment:
#   COMIN_HOLD_FILE  hold file path (injected by the module)
# `date` must be GNU coreutils date (the module's runtimeInputs).

hold_file="${COMIN_HOLD_FILE:?COMIN_HOLD_FILE not set}"

usage() {
  echo "usage: comin-hold set --by <who> --why <text> --for <N>h|<N>m (at most 12h) | show | clear" >&2
  exit 2
}
clean() { printf '%s' "$1" | tr -d '\000-\037\177' | cut -c1-200; }

case "${1:-}" in
  set)
    shift
    by="" why="" for=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --by) by="$(clean "${2:-}")" ;;
        --why) why="$(clean "${2:-}")" ;;
        --for) for="${2:-}" ;;
        *) usage ;;
      esac
      shift 2 || usage
    done
    [ -n "$by" ] || { echo "comin-hold: --by is required" >&2; exit 2; }
    [ -n "$why" ] || { echo "comin-hold: --why is required" >&2; exit 2; }
    [[ $for =~ ^([0-9]{1,5})([hm])$ ]] || usage
    unit=3600
    [ "${BASH_REMATCH[2]}" = h ] || unit=60
    seconds=$((10#${BASH_REMATCH[1]} * unit))
    if [ "$seconds" -le 0 ] || [ "$seconds" -gt 43200 ]; then
      echo "comin-hold: --for must be more than 0 and at most 12h" >&2
      exit 2
    fi
    now="$(date -u +%s)"
    tmp="$(mktemp "$hold_file.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    printf 'by=%s\nwhy=%s\nset=%s\nuntil=%s\n' "$by" "$why" \
      "$(date -u -d "@$now" +%Y-%m-%dT%H:%M:%SZ)" \
      "$(date -u -d "@$((now + seconds))" +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$hold_file"
    trap - EXIT
    cat "$hold_file"
    ;;
  show)
    if [ -f "$hold_file" ]; then
      tr -d '\000-\010\013-\037\177' < "$hold_file"
    else
      echo "comin-hold: no hold at $hold_file"
    fi
    ;;
  clear)
    rm -f "$hold_file"
    echo "comin-hold: cleared $hold_file"
    ;;
  *) usage ;;
esac
