#!/usr/bin/env bash
# Cluster-restore (worker Mac) — undo cluster-quiesce.sh after the cable is out.
#
# Bootstraps back exactly the agents the quiesce recorded (labels whose
# plists have since disappeared are skipped silently). GUI apps deliberately
# stay closed — the user reopens what they want.
#
# A machine-local restore denylist, one label pattern per line, excludes
# specific quiesced agents from ever coming back automatically (e.g. a
# recorder-type agent the operator wants to stay down through every cluster
# cycle). The file is optional and lives OUTSIDE this repo — it is per-machine
# state, never committed, and this script carries no opinion about what goes
# in it.

uid="$(id -u)"
state_file="$HOME/Library/Application Support/mlx-cluster/quiesced-agents"
denylist_file="$HOME/.config/cluster-quiesce/restore-denylist"

[ -f "$state_file" ] || {
  echo "cluster-restore: nothing recorded, nothing to do"
  exit 0
}

restored=0
excluded=0
failed=""
while IFS= read -r label; do
  [ -n "$label" ] || continue
  if [ -s "$denylist_file" ] && grep -qFf "$denylist_file" <<< "$label"; then
    excluded=$((excluded + 1))
    continue # matched the restore denylist: leave it quiesced, not a failure
  fi
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

[ "$excluded" -eq 0 ] || echo "cluster-restore: $excluded excluded agent(s) left quiesced (restore denylist: $denylist_file)"

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
