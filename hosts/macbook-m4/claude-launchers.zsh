# Custom-auth launchers for `claude` (Claude Code).
# Sibling of gh-token-switching.zsh; sourced from home.nix initContent.
#
# Provides:
#   av-claude <profile> [claude-args...]   aws-vault exec <profile> -- claude ...
#   gh-claude-restricted [claude-args...]  claude with GITHUB_TOKEN from the RESTRICTED tier
#   gh-claude-private    [claude-args...]  claude with GITHUB_TOKEN from the PRIVATE tier
#   gh-claude-dryvist    [claude-args...]  claude with GITHUB_TOKEN from the DRYVIST tier
#   gh-claude-admin      [claude-args...]  claude with GITHUB_TOKEN from the ADMIN tier
#   gh-claude-org-admin  [claude-args...]  claude with GITHUB_TOKEN from the ORG_ADMIN tier
#
# Each gh-claude-* wrapper runs its underlying gh-* function (defined in
# gh-token-switching.zsh) inside a subshell, so the GITHUB_TOKEN and
# GH_ENV_MODE exports those functions produce do NOT leak into the parent
# shell after claude exits. This preserves the shell's default least-privilege
# tier. The tier names (RESTRICTED / PRIVATE / ADMIN) correspond to the macOS
# Keychain service names GH_PAT_RESTRICTED / GH_PAT_PRIVATE / GH_PAT_ADMIN
# from which the underlying gh-* functions read the token.
#
# Every launcher prints a short status banner to stderr before invoking
# claude. The banner is primarily aimed at nested AI sessions: when a Claude
# Code agent invokes one of these functions via its bash tool, the banner
# lands in the tool output so the agent can see (a) that it is now running
# under a custom authentication context, (b) what kind of context it is,
# and (c) that the context disappears when the claude process exits. The
# banner contains no secrets or token material — only the source type and
# the context label passed into the launcher.

# Shared status banner emitted before claude is execed.
# Reusable across all launchers — takes an auth-source label and a
# context name. Prints to stderr so it doesn't collide with claude's
# stdout. No secret material is ever printed.
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

gh-claude-restricted() {
  (
    gh-restricted >/dev/null \
      && _claude_launchers_banner "github-token tier" "restricted" \
      && exec claude "$@"
  )
}

gh-claude-private() {
  (
    gh-private >/dev/null \
      && _claude_launchers_banner "github-token tier" "private" \
      && exec claude "$@"
  )
}

gh-claude-dryvist() {
  (
    gh-dryvist >/dev/null \
      && _claude_launchers_banner "github-token tier" "dryvist" \
      && exec claude "$@"
  )
}

gh-claude-admin() {
  (
    gh-admin >/dev/null \
      && _claude_launchers_banner "github-token tier" "admin" \
      && exec claude "$@"
  )
}

gh-claude-org-admin() {
  (
    gh-org-admin >/dev/null \
      && _claude_launchers_banner "github-token tier" "org-admin" \
      && exec claude "$@"
  )
}
