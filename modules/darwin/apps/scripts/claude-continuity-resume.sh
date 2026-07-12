# Reboot-continuity resume: relaunch an armed Claude Code mission at login.
# (Fragment for writeShellApplication — it supplies the shebang and strict mode.)
#
# Armed state lives in ~/.claude/run/continuity/ (runtime state, never nix):
#   armed-session-id  line 1 = Claude Code session id to resume
#                     line 2 = optional working directory (default: ~/git)
#   resume-prompt.md  optional continuation prompt (default points at
#                     RESUME-CONTINUITY.md in the state dir)
#
# Safety layers, in order:
#   1. Disarmed (no armed file)            -> no-op.
#   2. No reboot since arming (boottime)   -> no-op. Makes arming safe while
#      the original session is still alive, including the RunAtLoad fire that
#      darwin-rebuild triggers at apply time.
#   3. Cadence gate (durable marker)       -> repeated launchd fires within
#      the min interval do nothing.
#   4. Dedicated tmux session exists       -> no-op (already resumed).
#   5. Armed file is CONSUMED (renamed) only after a successful launch —
#      one-shot per arming, marker written after the work (loop-cadence).

STATE_DIR="$HOME/.claude/run/continuity"
ARMED="$STATE_DIR/armed-session-id"
MARKER="$STATE_DIR/last-fire"
MIN_INTERVAL=300
TMUX_SESSION="claude-continuity"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"

[ -f "$ARMED" ] || exit 0

# Fire only on the first login of a boot that happened AFTER arming.
boot_sec=$(/usr/sbin/sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+).*/\1/')
case "$boot_sec" in
'' | *[!0-9]*)
  # kern.boottime format changed or the regex missed — fail safe, stay armed.
  echo "claude-continuity: could not parse boot time ('$boot_sec'); standing by" >&2
  exit 0
  ;;
esac
armed_sec=$(/usr/bin/stat -f %m "$ARMED")
if [ "$boot_sec" -lt "$armed_sec" ]; then
  echo "claude-continuity: armed but no reboot since arming; standing by"
  exit 0
fi

now=$(date +%s)
last=$(cat "$MARKER" 2>/dev/null || echo 0)
if [ $((now - last)) -lt "$MIN_INTERVAL" ]; then
  exit 0
fi

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  exit 0
fi

session_id=$(head -n 1 "$ARMED" | tr -d '[:space:]')
if [ -z "$session_id" ]; then
  echo "claude-continuity: armed file is empty: $ARMED" >&2
  exit 1
fi

work_dir=$(sed -n '2p' "$ARMED")
work_dir="${work_dir:-$HOME/git}"

host=$(/bin/hostname -s)
attach_hint="ssh $host then: tmux attach -t $TMUX_SESSION"
if [ -f "$STATE_DIR/resume-prompt.md" ]; then
  prompt=$(cat "$STATE_DIR/resume-prompt.md")
else
  prompt="You were auto-resumed after a planned reboot. FIRST post a Slack status to the user's channel confirming the resume and your remote-control handle ($attach_hint) so the user can reach and steer you. Then read $STATE_DIR/RESUME-CONTINUITY.md and the mission plan it points at, verify current state, and continue the mission."
fi

# tmux execs a multi-argument command directly — no shell quoting layer, so
# the prompt and session id never transit a shell string.
tmux new-session -d -s "$TMUX_SESSION" -c "$work_dir" \
  "$CLAUDE_BIN" --resume "$session_id" --dangerously-skip-permissions "$prompt"

mv "$ARMED" "$STATE_DIR/fired-$now"
printf '%s\n' "$now" >"$MARKER"
echo "claude-continuity: resumed session $session_id in tmux session $TMUX_SESSION (cwd $work_dir)"
echo "claude-continuity: remote control: $attach_hint"
