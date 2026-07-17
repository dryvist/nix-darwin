#!/usr/bin/env bash
# Cluster-restore (worker Mac) — undo cluster-quiesce.sh after the cable is out.
#
# Bootstraps back exactly the agents the quiesce recorded (labels whose
# plists have since disappeared are skipped silently). GUI apps deliberately
# stay closed — the user reopens what they want.

uid="$(id -u)"
state_file="$HOME/Library/Application Support/mlx-cluster/quiesced-agents"

[ -f "$state_file" ] || {
  echo "cluster-restore: nothing recorded, nothing to do"
  exit 0
}

restored=0
failed=""
while IFS= read -r label; do
  [ -n "$label" ] || continue
  plist="$HOME/Library/LaunchAgents/$label.plist"
  [ -f "$plist" ] || continue # uninstalled since the quiesce: skip silently
  if launchctl bootstrap "gui/$uid" "$plist" 2> /dev/null; then
    restored=$((restored + 1))
  elif launchctl print "gui/$uid/$label" > /dev/null 2>&1; then
    # bootstrap refuses an already-loaded agent (e.g. a double restore):
    # loaded is the goal state, count it restored.
    restored=$((restored + 1))
  else
    failed="$failed$label"$'\n'
  fi
done < "$state_file"

if [ -n "$failed" ]; then
  # Keep only the labels that failed to come back: deleting the whole record
  # on a partial restore silently orphaned them with no retry path. A rerun
  # of cluster-restore (or the next link-down tick) picks them up.
  printf '%s' "$failed" > "$state_file"
  echo "cluster-restore: bootstrapped $restored agents; kept $(printf '%s' "$failed" | grep -c .) failed labels for retry" >&2
  exit 1
fi

rm -f "$state_file"
echo "cluster-restore: bootstrapped $restored agents back"
