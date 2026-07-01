# Custom-auth launcher for `claude` (Claude Code).
# Sourced from home.nix initContent.
#
# Provides:
#   av-claude <profile> [claude-args...]   aws-vault exec <profile> -- claude ...
#
# (The gh-claude-* GitHub-token relaunch wrappers were removed — they were
# unused. To run claude under a non-default GitHub token tier, switch the
# parent shell with the gh-* functions in gh-token-switching.zsh first, then
# launch claude.)
#
# av-claude prints a short status banner to stderr before invoking claude. The
# banner is aimed at nested AI sessions: when a Claude Code agent invokes it via
# its bash tool, the banner lands in the tool output so the agent can see (a)
# that it is now running under a custom authentication context, (b) what kind,
# and (c) that the context disappears when the claude process exits. The banner
# contains no secrets — only the source type and the context label.

# Status banner emitted before claude is execed. Prints to stderr so it doesn't
# collide with claude's stdout. No secret material is ever printed.
_claude_launchers_banner() {
  local source_type="$1"
  local context="$2"
  cat >&2 <<BANNER

[claude-launchers] custom authentication context is now active
  type:    ${source_type}
  context: ${context}
  scope:   this claude process only — the parent shell is unaffected

You now have the credentials and capabilities granted by this context.
Tools that auto-detect credentials from the environment (aws, gh, git,
terraform, kubectl, etc.) will pick them up automatically. Nothing
persists once claude exits; the parent shell's environment is untouched.

BANNER
}

av-claude() {
  if (( $# == 0 )); then
    echo "usage: av-claude <aws-vault-profile> [claude-args...]" >&2
    echo "       profiles: see ~/.aws/config" >&2
    echo "       e.g.  av-claude terraform" >&2
    echo "             av-claude tf-proxmox --resume" >&2
    return 2
  fi
  local profile="$1"
  shift
  _claude_launchers_banner "aws-vault profile" "$profile"
  aws-vault exec "$profile" -- claude "$@"
}
