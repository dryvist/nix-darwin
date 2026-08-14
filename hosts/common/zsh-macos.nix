# macOS-specific zsh overrides for the shared home-manager config.
#
# Split out of hosts/common/home.nix for the per-file byte cap. The base zsh
# config is provided by nix-home (sharedModule); these additions are
# macOS-specific and merge via the NixOS/home-manager module system. Holds the
# keychain API-key reads (non-GitHub) and the custom claude/macos launcher
# sourcing — all Mac-only. GitHub tokens now come exclusively from OpenBao via
# the openbao-github-creds git credential helper (see hosts/macbook-m4), not a
# keychain tier. References only lib, userConfig, and hostConfig; the ./*.zsh
# sources resolve from this directory.
{
  lib,
  nix-ai,
  pkgs,
  userConfig,
  hostConfig,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  vctPackages =
    if nix-ai ? packages && builtins.hasAttr system nix-ai.packages then
      nix-ai.packages.${system}
    else
      { };
  vctCriblPkg =
    if builtins.hasAttr "vct-cribl-cli" vctPackages then vctPackages.vct-cribl-cli else null;
  vctSplunkPkg =
    if builtins.hasAttr "vct-splunk-cli" vctPackages then vctPackages.vct-splunk-cli else null;
in
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
      # GitHub tokens are deliberately NOT read here — they come from OpenBao via
      # the openbao-github-creds git credential helper (see hosts/macbook-m4).

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

      # --- GitHub authentication ---
      # GitHub tokens are minted on demand by OpenBao (ephemeral GitHub App
      # installation tokens) through the openbao-github-creds git credential
      # helper, wired in hosts/macbook-m4. The former keychain GH_PAT tier
      # switching (gh-restricted / gh-dryvist / gh-admin / ...) has been retired.
      #
      # `git` needs nothing further. gh-auth.zsh adds gh-read / gh-claim /
      # gh-release for `gh` and anything else that reads GITHUB_TOKEN from the
      # environment — mint-at-call-time, never at shell init and never on disk.
      ${lib.optionalString (!hostConfig.isServer) ''
        source ${./gh-auth.zsh}
      ''}

      # --- VisiCore operator CLI launchers ---
      # Selectors come from the automation keychain at call time; Doppler
      # injects the actual credentials only into the child process.
      ${lib.optionalString (!hostConfig.isServer && vctCriblPkg != null && vctSplunkPkg != null) ''
        _vct_with_doppler() {
          local exe="$1"
          shift

          local doppler_project doppler_config
          doppler_project="$(_get_keychain_secret 'VCT_DOPPLER_PROJECT' "$_KC_AI_ACCOUNT" "$_KC_AI_DB")"
          doppler_config="$(_get_keychain_secret 'VCT_DOPPLER_CONFIG' "$_KC_AI_ACCOUNT" "$_KC_AI_DB")"

          if [ -z "$doppler_project" ] || [ -z "$doppler_config" ]; then
            print -u2 "[vct-cli] ERROR missing Doppler selector keychain entries for VCT_DOPPLER_PROJECT or VCT_DOPPLER_CONFIG"
            return 1
          fi

          doppler run -p "$doppler_project" -c "$doppler_config" -- "$exe" "$@"
        }

        _vct_cribl() {
          _vct_with_doppler ${lib.escapeShellArg (lib.getExe vctCriblPkg)} "$@"
        }

        _vct_splunk() {
          _vct_with_doppler ${lib.escapeShellArg (lib.getExe vctSplunkPkg)} "$@"
        }

        alias cribl='_vct_cribl'
        alias splunk='_vct_splunk'
      ''}

      unset _KC_USER _KC_AI_ACCOUNT _KC_AI_DB

      # --- Custom-auth launcher for `claude` ---
      # Defines av-claude <profile> (aws-vault exec <profile> -- claude).
      source ${./claude-launchers.zsh}

      # --- macOS setup ---
      source ${./macos-setup.zsh}
    '';
  };
}
