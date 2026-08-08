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
#
# QUIT BY BUNDLE ID, NEVER BY NAME. `tell application <name>` resolves the name
# through CFURLCreateFromApplicationNameAndContainer, and when no bundle matches
# — routine, because `name of every application process` yields PROCESS names,
# which are not always application names — AppleScript falls back to
# PromptUserForApplication: the "Where is…?" chooser, an NSApplication modal.
# Under launchd there is no one to answer it and no window to see, so the sweep
# parks forever. `with timeout` cannot save it; the block is in name resolution,
# before the timeout-guarded event send. Measured 2026-08-07: this wedged the
# worker's link-up for 14+ minutes between the rank-start boundary and the
# kickstart, so the coordinator struck out on peer-rendezvous and stood the pair
# down. `tell application id <bundleID>` resolves through LaunchServices, which
# returns an error instead of opening UI.
#
# SIGTERM instead of AppleScript was considered and rejected: quit events honor
# unsaved-work prompts and a signal does not, so the cheaper sweep is the one
# that loses a user's open documents.
default_terminals=$'Finder\nGhostty\nTerminal\niTerm2\nWezTerm\nAlacritty\nkitty'
terminals="${CLUSTER_QUIESCE_TERMINALS:-$default_terminals}"

# Belt to the bundle-id braces above. Quitting GUI apps is best-effort memory
# reclaim and is never worth blocking a rank start, so bound the whole sweep on
# the wall clock: a modal in a headless process is a CLASS of failure, not one
# bug, and the next member of it must cost a logged timeout rather than a window.
gui_timeout="${CLUSTER_QUIESCE_GUI_TIMEOUT:-30}"
rc=0
timeout -k 5 "$gui_timeout" /usr/bin/osascript - "$terminals" <<'EOF' || rc=$?
on run argv
    set AppleScript's text item delimiters to linefeed
    set keepList to text items of (item 1 of argv)
    tell application "System Events"
        set quitIds to {}
        repeat with p in (every application process whose background only is false)
            set bid to bundle identifier of p
            if (name of p) is not in keepList and bid is not missing value then
                set end of quitIds to bid
            end if
        end repeat
    end tell
    repeat with bid in quitIds
        try
            with timeout of 15 seconds
                tell application id (bid as text) to quit
            end timeout
        end try
    end repeat
end run
EOF
# 124 = timeout fired, 137 = the -k KILL that followed it.
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
  echo "cluster-quiesce: GUI quit sweep exceeded ${gui_timeout}s and was killed; continuing without it (rank start must not block on it)" >&2
elif [ "$rc" -ne 0 ]; then
  echo "cluster-quiesce: GUI quit sweep exited $rc; continuing" >&2
fi

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
