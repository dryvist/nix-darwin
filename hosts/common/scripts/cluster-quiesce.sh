#!/usr/bin/env bash
# Cluster-quiesce (worker Mac) — free memory/GPU for the cluster rank.
#
# Explicit KEEP allowlist: every user LaunchAgent whose label does not match
# the reviewed patterns below is booted out, and every visible GUI app is
# quit. What was booted out is recorded to a state file so cluster-restore.sh
# brings back exactly that set. The allowlist (not a kill list) keeps
# machine-specific agent names out of this public file and means a newly
# installed memory hog is quiesced by default instead of silently surviving.
#
# KEEP: nix-managed plumbing (com.nix-darwin.* — includes the log shippers),
# home-manager agents (org.nix-community.*), the cluster rank itself
# (dev.mlx-cluster.*), standalone log rotation (harmless, avoids a restore step),
# ssh/gpg agents, and git background maintenance.

uid="$(id -u)"
state_file="$HOME/Library/Application Support/mlx-cluster/quiesced-agents"
mkdir -p "$(dirname "$state_file")"

# Idempotence guard: a second quiesce before the restore would truncate the
# record while the agents are already booted out, losing the restore list.
# Create the state file atomically under `set -C` (noclobber) so two
# near-simultaneous invocations cannot both pass a check-then-truncate race —
# the create fails for whichever loses, and that one exits untouched.
if ! (set -C; : > "$state_file") 2> /dev/null; then
  echo "cluster-quiesce: active quiesce state detected; already quiesced"
  exit 0
fi

# 1. Quit every visible GUI app, honoring save prompts. Terminals are
#    excluded so a live cable test session cannot saw off its own branch.
#    The keep list is fed in via CLUSTER_QUIESCE_TERMINALS (newline-separated,
#    set by the module from programs.clusterQuiesce.terminalAllowlist) so a
#    session in any other terminal can be protected without editing this file.
default_terminals=$'Finder\nGhostty\nTerminal\niTerm2\nWezTerm\nAlacritty\nkitty'
terminals="${CLUSTER_QUIESCE_TERMINALS:-$default_terminals}"
/usr/bin/osascript - "$terminals" <<'EOF' || true
on run argv
    set AppleScript's text item delimiters to linefeed
    set keepList to text items of (item 1 of argv)
    tell application "System Events"
        set appNames to name of every application process whose background only is false
    end tell
    repeat with appName in appNames
        set appText to appName as text
        if appText is not in keepList then
            try
                with timeout of 15 seconds
                    tell application appText to quit
                end timeout
            end try
        end if
    end repeat
end run
EOF

# 2. Boot out every user agent not on the KEEP allowlist, recording each
#    label for restore. Only agents with a plist under ~/Library/LaunchAgents
#    are swept — those are the ones cluster-restore.sh can bootstrap back.
keep='^(com\.apple\.|org\.nix-community\.|com\.nix-darwin\.|dev\.mlx-cluster\.|org\.git-scm\.|com\.openssh\.)|^dev\.mlx-model-server\.logrotate$'
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

echo "cluster-quiesce: GUI apps quit; booted out $(wc -l < "$state_file" | tr -d ' ') agents"
