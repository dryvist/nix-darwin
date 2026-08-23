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
# NO APPLE EVENTS TO OTHER APPS — NSWorkspace/NSRunningApplication ONLY.
# `tell application "System Events"` and `tell application id <bid> to quit`
# both send Apple Events, which need per-target automation consent. Consent is
# keyed to the exact executable path of the responsible process, and that path
# changes across system generations — so a sweep that worked can start
# prompting again after a rebuild, and under launchd there is no one to answer
# the prompt and no window to see it: the send parks until the wall-clock bound
# kills it, reclaiming nothing (observed repeatedly, most recently 2026-08-22).
# NSWorkspace.runningApplications enumerates without consent, and
# NSRunningApplication.terminate() posts the same polite quit request the Dock
# sends — no consent, and it returns immediately instead of waiting for the
# app's reply, so an app sitting at a save prompt cannot stall the sweep.
#
# SIGTERM was considered and rejected: a polite quit honors unsaved-work
# prompts and a signal does not, so the cheaper sweep is the one that loses a
# user's open documents. terminate() keeps that property.
default_terminals=$'Finder\nGhostty\nTerminal\niTerm2\nWezTerm\nAlacritty\nkitty'
terminals="${CLUSTER_QUIESCE_TERMINALS:-$default_terminals}"

# Belt to the consent-free design above: a modal or blocked send in a headless
# process is a CLASS of failure, so any future member of it must cost a logged
# timeout rather than a wedged rank start. The sweep is best-effort memory
# reclaim and is never worth blocking on.
gui_timeout="${CLUSTER_QUIESCE_GUI_TIMEOUT:-30}"
rc=0
quit_log="$(timeout -k 5 "$gui_timeout" /usr/bin/osascript - "$terminals" <<'EOF'
use framework "AppKit"
on run argv
    set AppleScript's text item delimiters to linefeed
    set keepList to text items of (item 1 of argv)
    set quitNames to {}
    set apps to current application's NSWorkspace's sharedWorkspace()'s runningApplications()
    repeat with a in apps
        -- activationPolicy 0 = regular (visible, Dock) apps only
        if (a's activationPolicy() as integer) is 0 then
            set n to a's localizedName()
            if n is not missing value and (n as text) is not in keepList then
                a's terminate()
                set end of quitNames to (n as text)
            end if
        end if
    end repeat
    set AppleScript's text item delimiters to ", "
    return quitNames as text
end run
EOF
)" || rc=$?
# Log every quit decision: a sweep that reclaims nothing must say so.
echo "cluster-quiesce: GUI quit requested for: ${quit_log:-<none>}" >&2
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
