#!/usr/bin/env bash
# Night-restore (worker Mac) — undo night-quiesce.sh after the cable is out.
#
# Bootstraps back exactly the agents the quiesce recorded (labels whose
# plists have since disappeared are skipped silently). GUI apps deliberately
# stay closed — it is morning, the user reopens what they want.

uid="$(id -u)"
state_file="$HOME/Library/Application Support/mlx-night/quiesced-agents"

[ -f "$state_file" ] || {
  echo "night-restore: nothing recorded, nothing to do"
  exit 0
}

restored=0
while IFS= read -r label; do
  [ -n "$label" ] || continue
  plist="$HOME/Library/LaunchAgents/$label.plist"
  if [ -f "$plist" ] && launchctl bootstrap "gui/$uid" "$plist" 2> /dev/null; then
    restored=$((restored + 1))
  fi
done < "$state_file"

rm -f "$state_file"
echo "night-restore: bootstrapped $restored agents back"
