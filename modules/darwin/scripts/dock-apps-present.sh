#!/usr/bin/env bash
# Warn when a path declared for a Dock tile is no longer present on disk.

total=$#
found=0

for path in "$@"; do
  if [ -e "$path" ]; then
    found=$((found + 1))
  else
    printf '%s [ERROR] dock app missing: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$path" >&2 || true
  fi
done

printf '%s [INFO] dock apps present: %s/%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$found" "$total" || true
