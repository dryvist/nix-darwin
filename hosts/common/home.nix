# Shared home-manager configuration
#
# Imported by every host's home.nix. Holds host-agnostic user environment and
# consumes registry parameters (OTEL host.name, MLX sizing, OrbStack volume).
# Host-specific home config — the TCC-sensitive GUI app list — stays in
# hosts/<label>/home.nix.

{
  config,
  lib,
  pkgs,
  userConfig,
  osConfig,
  hostConfig,
  ...
}:

{
  imports = [
    # services.aiStack.defaultLocalModelId — supplied from the committed
    # lib/hosts.nix (non-secret model id). Extracted to keep files under the
    # per-file size cap.
    ./services-ai-stack.nix
    # Disables nix-ai's auto-discovery of locally-cached HF models so the
    # registry stays at the single defaultLocalModelId entry.
    ./mlx-no-autodiscover.nix
    # Global git excludes seeded from the dryvist org-default (see module).
    ./git-global-excludes.nix
  ];

  # Share system-level Homebrew taps with nix-ai's trust.json.
  # homebrew.taps entries can be strings or submodule attrsets (nix-darwin
  # normalizes to attrsets with a `name`); the nix-ai option takes strings.
  programs.ai-homebrew.trustedTaps = map (
    t: if builtins.isString t then t else t.name
  ) osConfig.homebrew.taps;

  # ==========================================================================
  # macOS Application Management (copyApps for TCC stability)
  # ==========================================================================
  # Use copyApps instead of linkApps to create REAL copies of apps at stable
  # paths in ~/Applications/Home Manager Apps/. This allows macOS TCC
  # (Transparency, Consent, Control) permissions to persist across rebuilds.
  #
  # With linkApps (default), apps symlink to /nix/store paths which change on
  # every rebuild, invalidating TCC permissions (camera, mic, screen recording).
  #
  # Trade-off: Uses more disk space (~100MB per app) but TCC permissions persist.
  #
  # See: https://github.com/nix-community/home-manager/issues/8336
  targets.darwin = {
    copyApps.enable = true;
    linkApps.enable = false;
  };

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  # Upstream: https://github.com/nix-community/home-manager/issues/7935
  # TODO: Re-enable when upstream fixes options.json context in manual.nix
  manual.manpages.enable = false;

  # nix-home role preset: `workstation` enables all daily-driver GUI/desktop
  # features; `server` drops them. Driven by the host's registry `class`
  # (normalized in flake.nix mkHost, so the attr always exists).
  home-profile.preset = hostConfig.class;

  # ==========================================================================
  # Monitoring / Observability
  # ==========================================================================
  # Enable monitoring infrastructure (K8s manifests, helper scripts). The OTEL
  # resource host.name is the host's network name (single identity source).
  monitoring = {
    enable = true;
    kubernetes.enable = true;
    otel = {
      enable = true;
      # endpoint defaults to http://localhost:30317 (NodePort gRPC)
      logPrompts = true;
      logToolDetails = true;
      resourceAttributes = {
        "host.name" = hostConfig.hostName;
      };
    };
    cribl.enable = true;
  };

  programs = {
    # Claude Code config (plugin disables, MCP server overrides) moved to
    # nix-ai/modules/claude-config.nix in dryvist/nix-ai#853 — Claude config
    # doesn't belong in nix-darwin (host-specific opinion lives in nix-ai).

    # cecli (nix-ai's Aider fork) is disabled — unused, and its
    # tree-sitter-language-pack<=0.13.0 pin fails to build on nixpkgs 26.05
    # (which ships 1.4.1). mkForce overrides nix-ai's unconditional enable
    # (modules/default.nix). Re-enable in nix-ai once the dep bound is relaxed.
    cecli.enable = lib.mkForce false;

    # Local MLX inference server (vllm-mlx + llama-swap proxy on :11434).
    # Brings the existing vllm-mlx LaunchAgent under Nix management — without
    # this, the registry at services.aiStack.models is materialized to nothing
    # and llama-swap.json drifts from whatever was last activated by hand.
    # Sizing (cacheMemoryMb / prefillBatchSize) is per-host from the registry.
    # Gated on the host defining `mlx` so a non-inference host is left untouched
    # (no MLX server) rather than crashing on a missing attr.
    mlx = lib.mkIf (hostConfig ? mlx) ({ enable = true; } // hostConfig.mlx);

    # macOS-specific zsh overrides
    # Base zsh config provided by nix-home (sharedModule).
    # These additions are macOS-specific and merge via NixOS module system.
    zsh = {
      oh-my-zsh.plugins = [
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
  };

  # ==========================================================================
  # OrbStack external-volume wiring (only when the host enables OrbStack)
  # ==========================================================================
  # Nix does NOT manage the volume contents — it only creates the symlink. The
  # volume itself is created by a launchd daemon (modules/darwin/apps/orbstack.nix).
  home = {
    # Ghostty terminfo (just the DB, not the GUI app) on every host so SSHing
    # in from a Ghostty terminal — which sets TERM=xterm-ghostty — resolves
    # cleanly even on a headless server that drops the workstation GUI package
    # list. Must be the `-bin` variant: ghostty.terminfo (source build) fails
    # its darwin assert. macbook-m4 already pulls this store path via ghostty-bin.
    packages = [ pkgs.ghostty-bin.terminfo ];

    file = lib.mkIf (hostConfig.orbstack.enable or false) {
      # Symlink the entire Group Container so ALL OrbStack data (Docker images,
      # containers, volumes, Linux VMs, logs) lives on the dedicated APFS volume.
      # MIGRATION: Stop OrbStack and move existing data before enabling.
      # NOTE: `ln` reports a permission error when OrbStack is running because the
      # Group Container directory is locked. This is expected — the symlink persists
      # correctly and does not need to be recreated on every rebuild.
      "Library/Group Containers/HUAQ24HBR6.dev.orbstack".source =
        config.lib.file.mkOutOfStoreSymlink "/Volumes/${hostConfig.orbstack.containerVolume}";

      # Docker daemon configuration for OrbStack: log rotation + build cache GC to
      # prevent unbounded disk growth. force = true: OrbStack pre-creates this file;
      # home-manager must overwrite it.
      ".orbstack/config/docker.json" = {
        force = true;
        text = builtins.toJSON (
          let
            logMaxFileSize = "25m";
            logMaxFiles = "25";
            keepDuration = "2160h"; # 90 days
            defaultKeepStorage = "10GB";
            sourceLocalMaxUsedSpace = "10GB";
            generalMaxUsedSpace = "20GB";
          in
          {
            log-driver = "json-file";
            log-opts = {
              max-size = logMaxFileSize;
              max-file = logMaxFiles;
            };
            builder.gc = {
              enabled = true;
              inherit defaultKeepStorage;
              policy = [
                {
                  inherit keepDuration;
                  filter = [ "type==source.local" ];
                  maxUsedSpace = sourceLocalMaxUsedSpace;
                }
                {
                  inherit keepDuration;
                  maxUsedSpace = generalMaxUsedSpace;
                }
              ];
            };
          }
        );
      };
    };

    sessionVariables = lib.mkIf (hostConfig.orbstack.enable or false) {
      # Container data on the dedicated external volume.
      CONTAINER_DATA = "/Volumes/${hostConfig.orbstack.containerVolume}";
    };
  };
}
