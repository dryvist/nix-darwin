#!/usr/bin/env bash
# Night-quiesce (worker Mac) — free memory/GPU for the night rank.
#
# Explicit KEEP allowlist: every user LaunchAgent whose label does not match
# the reviewed patterns below is booted out, and every visible GUI app is
# quit. What was booted out is recorded to a state file so night-restore.sh
# brings back exactly that set. The allowlist (not a kill list) keeps
# machine-specific agent names out of this public file and means a newly
# installed memory hog is quiesced by default instead of silently surviving.
#
# KEEP: nix-managed plumbing (com.nix-darwin.* — includes the log shippers),
# home-manager agents (org.nix-community.*), the night cluster itself
# (dev.mlx-night.*), day-log rotation (harmless, avoids a restore step),
# ssh/gpg agents, and git background maintenance.

uid="$(id -u)"
state_file="$HOME/Library/Application Support/mlx-night/quiesced-agents"
mkdir -p "$(dirname "$state_file")"
: > "$state_file"

# 1. Quit every visible GUI app, honoring save prompts. Terminals are
#    excluded so a plug-night test session cannot saw off its own branch.
/usr/bin/osascript <<'EOF' || true
tell application "System Events"
    set appNames to name of every application process whose background only is false
end tell
repeat with appName in appNames
    set appText to appName as text
    if appText is not in {"Finder", "Ghostty", "Terminal", "iTerm2", "WezTerm", "Alacritty", "kitty"} then
        try
            with timeout of 15 seconds
                tell application appText to quit
            end timeout
        end try
    end if
end repeat
EOF

# 2. Boot out every user agent not on the KEEP allowlist, recording each
#    label for restore. Only agents with a plist under ~/Library/LaunchAgents
#    are swept — those are the ones night-restore.sh can bootstrap back.
keep='^(com\.apple\.|org\.nix-community\.|com\.nix-darwin\.|dev\.mlx-night\.|org\.git-scm\.|com\.openssh\.)|^dev\.vllm-mlx\.logrotate$'
for plist in "$HOME/Library/LaunchAgents/"*.plist; do
  [ -f "$plist" ] || continue
  label="$(basename "$plist" .plist)"
  if [[ "$label" =~ $keep ]]; then
    continue
  fi
  if launchctl bootout "gui/$uid/$label" 2> /dev/null; then
    printf '%s\n' "$label" >> "$state_file"
  fi
done

echo "night-quiesce: GUI apps quit; booted out $(wc -l < "$state_file" | tr -d ' ') agents"
