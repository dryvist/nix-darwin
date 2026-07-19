# macOS-specific zsh overrides for the shared home-manager config.
#
# Split out of hosts/common/home.nix for the per-file byte cap. The base zsh
# config is provided by nix-home (sharedModule); these additions are
# macOS-specific and merge via the NixOS/home-manager module system. Holds the
# keychain API-key reads, the GitHub tiered-token switching setup, and the
# custom claude/macos launcher sourcing — all Mac-only. References only lib,
# userConfig, and hostConfig; the ./*.zsh sources resolve from this directory.
{
  lib,
  userConfig,
  hostConfig,
  ...
}:
{
  programs.zsh = {
    # mkBefore preserves the pre-split merge order (macos ahead of nix-home's
    # default-priority plugins) so the generated .zshrc stays byte-identical to
    # when this block lived inline in home.nix.
    oh-my-zsh.plugins = lib.mkBefore [
      "macos" # macOS utilities (ofd, cdf, etc.)
    ];

    # macOS-specific shell init (appended after cross-platform initContent from nix-home)
    initContent = lib.mkAfter ''
      # --- Keychain helper (persists for runtime token switching) ---

      _get_keychain_secret() {
        # Fetch a secret from the macOS Keychain by service name.
        # Usage: _get_keychain_secret <service> <account> [keychain-db]
        # keychain-db: optional path, e.g. automation.keychain-db
        security find-generic-password -s "$1" -a "$2" -w ''${3:+"$3"} 2>/dev/null || echo ""
      }

      # Keychain identity constants — resolved from userConfig at build time.
      # Human account: personal secrets in the login keychain.
      # AI account: automation secrets in a dedicated keychain (see lib/user-config.nix).
      _KC_USER='${userConfig.user.name}'
      _KC_AI_ACCOUNT='${userConfig.keychain.aiAccount}'
      _KC_AI_DB='${userConfig.keychain.aiDb}'

      # --- API Keys (from macOS Keychain) ---

      # GitHub - for github@claude-plugins-official MCP server
      export GITHUB_PERSONAL_ACCESS_TOKEN=''${GITHUB_PERSONAL_ACCESS_TOKEN:-"$(_get_keychain_secret 'github-pat' "$_KC_USER")"}

      # Context7 - for context7@claude-plugins-official MCP server
      export CONTEXT7_API_KEY=''${CONTEXT7_API_KEY:-"$(_get_keychain_secret 'CONTEXT7_API_KEY' "$_KC_USER")"}

      # HuggingFace - for huggingface MCP server and hf CLI (model downloads)
      ${
        # Server-class hosts are keychain-free for real secrets: HF_TOKEN
        # comes from the sops-rendered per-machine secret instead (portable
        # across machines via the committed encrypted file + on-device age
        # key). Workstations keep the keychain read, byte-identical.
        if hostConfig.isServer then
          ''export HF_TOKEN=''${HF_TOKEN:-"$(cat /run/secrets/HF_TOKEN 2>/dev/null || echo "")"}''
        else
          ''export HF_TOKEN=''${HF_TOKEN:-"$(_get_keychain_secret 'HF_TOKEN' "$_KC_AI_ACCOUNT" "$_KC_AI_DB")"}''
      }

      # openHarness local-LLM bearer (workstation only; no server sops fallback).
      ${lib.optionalString (!hostConfig.isServer) ''
        export OPENAI_API_KEY=''${OPENAI_API_KEY:-"$(_get_keychain_secret 'OPENAI_API_KEY' "$_KC_AI_ACCOUNT" "$_KC_AI_DB")"}
      ''}

      unset -f _get_keychain_secret  # No longer needed after init
      unset _KC_USER _KC_AI_DB  # _KC_AI_ACCOUNT persists for runtime gh-token switching

      # --- GitHub Token Context Switching (workstation only) ---
      # Server-class hosts are keychain-free (matching HF_TOKEN above): their
      # only GitHub need is the Actions runner, which authenticates via the
      # sops-rendered GH_RUNNER_PAT, not this interactive tiered-PAT flow. On a
      # server the whole block is omitted, so `gh-dryvist` never runs against a
      # non-existent automation.keychain-db (which otherwise errors on login).
      ${lib.optionalString (!hostConfig.isServer) ''
        _GH_SVC_RESTRICTED='${userConfig.github.tokens.restricted.service}'
        _GH_DB_RESTRICTED='${userConfig.github.tokens.restricted.keychain}'
        _GH_SVC_PRIVATE='${userConfig.github.tokens.private.service}'
        _GH_DB_PRIVATE='${userConfig.github.tokens.private.keychain}'
        _GH_SVC_DRYVIST='${userConfig.github.tokens.dryvist.service}'
        _GH_DB_DRYVIST='${userConfig.github.tokens.dryvist.keychain}'
        _GH_SVC_ADMIN='${userConfig.github.tokens.admin.service}'
        _GH_DB_ADMIN='${userConfig.github.tokens.admin.keychain}'
        _GH_SVC_ORG_ADMIN='${userConfig.github.tokens.orgAdmin.service}'
        _GH_DB_ORG_ADMIN='${userConfig.github.tokens.orgAdmin.keychain}'

        source ${./gh-token-switching.zsh}

        # Default to the dryvist tier on every new shell. dryvist's token lives
        # in the auto-readable automation keychain, so this loads with no password
        # prompt. This is NOT least-privilege — every shell + AI session defaults
        # to dryvist write access — a deliberate popups-vs-privilege tradeoff
        # (2026-05-28). Use gh-private / gh-admin / gh-org-admin to elevate further.
        unset GITHUB_TOKEN
        gh-dryvist
      ''}

      # --- Custom-auth launcher for `claude` ---
      # Defines av-claude <profile> (aws-vault exec <profile> -- claude). The
      # gh-claude-* GitHub-token relaunch wrappers were removed as unused; to
      # run claude under a non-default tier, switch the parent shell with the
      # gh-* functions sourced above first.
      source ${./claude-launchers.zsh}

      # --- macOS setup ---
      source ${./macos-setup.zsh}
    '';
  };
}
