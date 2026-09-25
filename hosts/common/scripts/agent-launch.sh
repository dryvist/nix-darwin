#!/usr/bin/env bash
# agent-launch - run an agent CLI as its automation identity.
#
# The operator's shell wraps each tool listed in lib/user-config.nix
# `agentUsers.<identity>.tools` (agent-launchers.nix), so typing `claude` runs
# Claude Code as the `claude` account instead of the operator's. One Touch ID
# prompt per launch: sudo's timestamp is disabled globally.
#
# The session starts in $GIT_HOME/<tool>, where $GIT_HOME is the IDENTITY's
# own workspace root (its home-manager `workspace.gitHome`), never an operator
# checkout. The agent clones what a task needs there with its own GitHub
# access; the operator may wipe the folder at any time and it is recreated.
#
# Usage: agent-launch <identity> <tool> [tool-args...]

identity="${1:?usage: agent-launch <identity> <tool> [args...]}"
tool="${2:?usage: agent-launch <identity> <tool> [args...]}"
shift 2

cat >&2 <<BANNER
[agent-launch] ${tool} as '${identity}' in its \$GIT_HOME/${tool}
  Clone what the task needs there with this identity's own GitHub access.
  Elevated OpenBao work: name the inert role (openbao-policy-sync,
  ai-apply-<svc>, ai-admin); the operator does one userpass + TOTP unlock.
  Never the root break-glass token.
BANNER

# Runs as the identity, in its login shell (so its session variables are set):
# create the workspace owner-only if wiped, enter the tool folder, exec.
inner=$(
  cat <<'INNER'
: "${GIT_HOME:?GIT_HOME is unset for this identity}"
mkdir -p "$GIT_HOME/$1" && chmod 700 "$GIT_HOME" && cd "$GIT_HOME/$1" && exec "$@"
INNER
)

exec sudo -u "$identity" -i sh -c "$inner" _ "$tool" "$@"
