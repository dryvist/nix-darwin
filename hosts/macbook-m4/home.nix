# macbook-m4 Home Configuration
#
# User environment for macbook-m4 host.
# Cross-platform settings provided by nix-home (sharedModule).
# AI CLI settings provided by nix-ai (sharedModule).
# This file adds macOS-specific overrides and host-specific settings.

{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}:

{
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

  # ==========================================================================
  # Host-Specific Home Settings
  # ==========================================================================
  # Settings unique to this machine's user environment

  # Enable monitoring infrastructure (K8s manifests, helper scripts)
  monitoring = {
    enable = true;
    kubernetes.enable = true;
    otel = {
      enable = true;
      # endpoint defaults to http://localhost:30317 (NodePort gRPC)
      logPrompts = true;
      logToolDetails = true;
      resourceAttributes = {
        "host.name" = "macbook-m4";
      };
    };
    cribl.enable = true;
  };

  programs = {
    claude = {
      # Disable playwright plugin globally — only useful in specific projects.
      # playwright@claude-skills (skills-only, no MCP) stays enabled.
      plugins.enabled."playwright@claude-plugins-official" = lib.mkForce false;

      # Auto-mode classifier context. Tells Claude Code's auto-mode
      # classifier (https://code.claude.com/docs/en/auto-mode-config)
      # which infrastructure to treat as trusted/internal. Without it,
      # the classifier defaults to trusting only the working repo and
      # blocks routine cross-repo / cross-org / cloud / homelab ops.
      # Lands at top-level `autoMode` in settings.json via nix-ai's
      # programs.claude.settings.autoMode option.
      settings.autoMode.environment = [
        "$defaults"
        "Single-developer personal homelab plus day-job (Splunk/Cribl architect). Public docs map: https://docs.jacobpevans.com (source github.com/JacobPEvans/docs) covers Infrastructure, Nix ecosystem, AI development, Observability, Security, and Tools surfaces."
        "Source control: GitHub orgs github.com/JacobPEvans/* and github.com/dryvist/*. All public repos under both are trusted to clone, push, branch, and PR-mutate against. Force-push to feature branches is routine; force-push to main is off-limits."
        "Workspace layout: ~/git/<repo>/main is the main-branch worktree. Feature work happens in ~/git/<repo>/<type>/<name>/ via git worktrees. Standard across every repo."
        "Cloud: AWS via aws-vault profiles (terraform-aws, terraform-aws-bedrock); Proxmox cluster on the home LAN (terraform-proxmox plus ansible-proxmox-*). No multi-tenant production."
        "Secrets stores: Doppler (ai-ci-automation/prd project carries AI/MCP keys); macOS Keychain (ai-secrets keychain holds ANTHROPIC_API_KEY etc.; elevate-access keychain holds elevated GH tokens via the RESTRICTED/PRIVATE/ADMIN tier system); Mozilla SOPS handles at-rest encryption; Bitwarden vault plus Bitwarden Secrets Manager. No long-lived AWS keys — OIDC handles CI."
        "AI runtimes: local MLX server on this Mac (mlx-server devenv shell); Claude / Codex / Gemini / Copilot CLIs all routed through local dev shells; PAL MCP proxy handles multi-model orchestration; HuggingFace CLI handles model management."
        "Observability stack: OpenTelemetry instrumentation → Cribl Stream → Splunk Enterprise (homelab). splunk-dev devenv shell on local Splunk work."
        "Self-hosted runners: GitHub Actions self-hosted RunsOn runners labeled per the JacobPEvans/.github v3 catalog. Jobs targeting RunsOn labels are routine."
        "Container deployment: LXC on Proxmox is the default in production homelab workloads. Docker only on vendor-locked images that require it (high-throughput network traffic must never flow through Docker's virtualized networking)."
        "Nix-first: nix-darwin (macOS), nix-home (cross-platform user env), nix-ai (AI tooling), nix-devenv (reusable dev shells plus flakeModules.dev-hygiene), nix-claude-code (Claude Code declarative module). Flakes-only — never use nix-env."
        "Pre-commit, linting, format: pre-commit hooks come from nix-devenv.flakeModules.dev-hygiene in Nix repos. zizmor policy from dryvist/.github (trusted publishers: actions/*, DeterminateSystems/*, googleapis/* may use ref-pins; everything else requires hash-pins)."
      ];

      # Disable MCP servers that duplicate built-in tools, are demo/test, or are project-specific.
      # Servers remain defined (for type validation) but disabled = true excludes them from ~/.claude.json.
      # Project-specific servers (cribl, terraform, aws) are re-enabled via per-project .mcp.json.
      mcpServers =
        lib.genAttrs
          [
            "everything" # Demo/test — not useful in production
            "filesystem" # Duplicates built-in Read/Write/Glob/Edit tools
            "fetch" # Duplicates built-in WebFetch tool
            "git" # Duplicates built-in git via Bash(git:*)
            "github" # Duplicates github@claude-plugins-official plugin
            "cribl" # Project-specific — available via per-project .mcp.json
            "terraform" # Project-specific — available via per-project .mcp.json
            "cloudflare" # Not actively used — disable until needed
            "exa" # Not actively used — disable until needed
            "firecrawl" # Not actively used — disable until needed
            "docker" # Not actively used — disable until needed
          ]
          (_: {
            disabled = true;
          })
        // {
          splunk = {
            command = "doppler-mcp";
            args = [ "splunk-mcp-connect" ];
            # TLS bypass for self-signed cert is scoped inside splunk-mcp-connect,
            # not here, to avoid leaking NODE_TLS_REJECT_UNAUTHORIZED to doppler-mcp.
          };
        };
    };

    # Local MLX inference server (vllm-mlx + llama-swap proxy on :11434).
    # Brings the existing vllm-mlx LaunchAgent under Nix management — without
    # this, the registry at services.aiStack.models is materialized to nothing
    # and llama-swap.json drifts from whatever was last activated by hand.
    mlx.enable = true;

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
        export HF_TOKEN=''${HF_TOKEN:-"$(_get_keychain_secret 'HF_TOKEN' "$_KC_AI_ACCOUNT" "$_KC_AI_DB")"}

        unset -f _get_keychain_secret  # No longer needed after init
        unset _KC_USER _KC_AI_DB  # _KC_AI_ACCOUNT persists for runtime gh-token switching

        # --- GitHub Token Context Switching ---
        _GH_SVC_RESTRICTED='${userConfig.github.tokens.restricted.service}'
        _GH_DB_RESTRICTED='${userConfig.github.tokens.restricted.keychain}'
        _GH_SVC_PRIVATE='${userConfig.github.tokens.private.service}'
        _GH_DB_PRIVATE='${userConfig.github.tokens.private.keychain}'
        _GH_SVC_ADMIN='${userConfig.github.tokens.admin.service}'
        _GH_DB_ADMIN='${userConfig.github.tokens.admin.keychain}'

        source ${./gh-token-switching.zsh}

        # Default to lowest privilege on every new shell
        unset GITHUB_TOKEN
        gh-restricted

        # --- Custom-auth launchers for `claude` ---
        # Defines av-claude <profile>, gh-claude-restricted, gh-claude-private,
        # gh-claude-admin. Depends on the gh-* functions sourced above.
        source ${./claude-launchers.zsh}

        # --- macOS setup ---
        source ${./macos-setup.zsh}
      '';
    };
  };

  home = {
    # ========================================================================
    # TCC-Sensitive GUI Applications (using copyApps for stable paths)
    # ========================================================================
    # These apps need macOS TCC (Transparency Consent Control) permissions
    # for camera, microphone, screen recording, etc.
    #
    # With targets.darwin.copyApps enabled (see above), apps in home.packages
    # are COPIED to ~/Applications/Home Manager Apps/ with STABLE paths that
    # persist TCC permissions across darwin-rebuild.
    #
    # This is better than mac-app-util trampolines because:
    # - Binary paths are stable (not /nix/store which changes on rebuild)
    # - TCC permissions granted to the app persist
    # - No wrapper scripts - actual app copies
    #
    # Trade-off: Uses more disk space (~100MB per app) but TCC works correctly.
    #
    # NOTE: OrbStack managed via programs.orbstack module at system-level.
    # See hosts/macbook-m4/default.nix for OrbStack configuration.
    packages = with pkgs; [
      # Terminal & Development
      ghostty-bin # Terminal emulator - needs Full Disk Access for darwin-rebuild
      rapidapi # Full-featured HTTP client for testing and describing APIs (sandboxed — auto-update prevention not possible)

      # AI IDEs & Tools (nixpkgs - stable TCC paths via copyApps)
      code-cursor # Cursor AI IDE (VS Code fork)
      chatgpt # OpenAI ChatGPT desktop app
      claudebar # Menu bar app for AI coding assistant quota monitoring

      # Communication
      discord # Voice/video chat - copyApps gives TCC-stable path for camera/mic permissions
      # zoom-us # DISABLED - no longer using Zoom

      # CLI / Media tools (non-GUI, no .app bundle)
      ffmpeg # Complete solution to record, convert and stream audio and video
    ];

    # ========================================================================
    # Host-specific symlinks for external volumes
    # ========================================================================
    # NOTE: These symlinks point to data on external volumes.
    # Nix does NOT manage the volume contents - only creates symlinks.
    file = {
      # OrbStack data on dedicated APFS volume
      # Symlinks entire Group Container so ALL OrbStack data lives on volume
      # Volume created by launchd daemon (see modules/darwin/apps/orbstack.nix)
      # Contains: Docker images, containers, volumes, Linux VMs, logs
      # MIGRATION: Stop OrbStack and move existing data before enabling
      # NOTE: `ln` reports a permission error when OrbStack is running because the
      # Group Container directory is locked. This is expected — the symlink persists
      # correctly and does not need to be recreated on every rebuild.
      "Library/Group Containers/HUAQ24HBR6.dev.orbstack".source =
        config.lib.file.mkOutOfStoreSymlink "/Volumes/ContainerData";

      # Docker daemon configuration for OrbStack
      # Log rotation + build cache GC to prevent unbounded disk growth
      # force = true: OrbStack pre-creates this file; home-manager must overwrite it
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

    # ========================================================================
    # Environment variables for external data locations
    # ========================================================================
    sessionVariables = {
      # Container data on dedicated volume
      # NOTE: This volume is separate from Ollama
      CONTAINER_DATA = "/Volumes/ContainerData";
    };
  };
}
