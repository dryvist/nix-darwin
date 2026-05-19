# Homebrew Configuration
#
# Homebrew is a FALLBACK ONLY for packages not in nixpkgs or severely outdated.
# Prefer nixpkgs for everything - only use homebrew when absolutely necessary.
#
# == Update Philosophy ==
#
# Packages are kept current via `brew autoupdate` (homebrew/autoupdate tap), which
# runs `brew update && brew upgrade --greedy --cleanup` every 30 hours in the
# background via a launchd LaunchAgent. The autoupdate plist is (re)created on
# every `darwin-rebuild switch` via a postActivation script.
#
# Our configuration:
#   - onActivation.autoUpdate = false  → Keeps rebuilds fast (no 45MB index download)
#   - onActivation.upgrade = false     → Rebuilds don't run brew upgrade (autoupdate handles it)
#   - brew autoupdate: every 30h       → Background upgrade with --greedy --cleanup
#   - Passive auto-update: Enabled     → >5 minutes trigger on command invocation
#
# == How Packages Get Updated ==
#
# 1. AUTOMATIC: brew autoupdate runs every 30 hours (background launchd agent)
# 2. MANUAL: Run `brew update && brew upgrade --greedy` for immediate updates
# 3. RENOVATE: Cannot track homebrew versions (no version info in this config)
#
# == Why Renovate Can't Help ==
#
# nix-darwin homebrew config contains only package names, not versions.
# Homebrew lacks declarative version pinning within configuration files.
# Renovate's homebrew manager only works with Ruby Formula files.
#
# NOTE: nix-darwin does NOT support version pinning for individual homebrew packages.
# To prevent upgrades for a specific package, pin it via `brew pin <package>`.

{
  lib,
  pkgs,
  nix-ai,
  ...
}:

let
  # 30 hours in seconds — brew autoupdate requires interval in seconds
  autoupdateInterval = 108000;

  # Brew formulae required by per-agent nix-ai modules whose preferred
  # install source is Homebrew (e.g. programs.qwen-code with
  # installVia = "brew"). The list is owned by the agent's module in
  # nix-ai and exported as a flake output, so each module stays
  # self-contained. See nix-ai/docs/architecture/per-agent-flakes.md.
  agentBrewFormulae = nix-ai.lib.brewFormulae or [ ];

  configureBrewAutoupdateScript = pkgs.writeShellApplication {
    name = "configure-brew-autoupdate";
    runtimeInputs = [ ];
    text = builtins.readFile ./scripts/configure-brew-autoupdate.sh;
  };
in
{
  homebrew = {
    enable = true;
    onActivation = {
      # Don't download 45MB index on every rebuild - keeps rebuilds fast and deterministic.
      # Homebrew's passive auto-update still works (triggers on command invocation after >5 minutes).
      autoUpdate = false;
      cleanup = "none"; # Don't remove manually installed packages
      # Upgrades handled by brew autoupdate (every 30h) — not during darwin-rebuild.
      # This keeps rebuilds fast. Run `brew upgrade --greedy` manually for immediate updates.
      upgrade = false;
    };
    taps = [
      "homebrew/autoupdate" # Background auto-update via launchd (brew autoupdate)
    ];
    brews = [
      # CLI tools (only if not available in nixpkgs)
      "ccusage" # Claude Code usage analyzer - not in nixpkgs

      # Gemini CLI (Google Gemini AI assistant)
      # - Moved from nixpkgs due to severe version lag (v0.23 vs v0.29 upstream)
      # - Homebrew version is required for Gemini 3.1 Pro support
      "gemini-cli"

      # --- AI Agent Tools (homebrew-only; home-manager cannot manage brew formulas) ---

      # Block Goose AI agent (https://github.com/block/goose)
      # - Using homebrew as nixpkgs version was >30 days old at time of addition; homebrew actively maintained
      # - Named 'block-goose-cli' to avoid conflict with nixpkgs 'goose' (database migration tool)
      "block-goose-cli"

      # Swift native on-device speech recognition (Apple Silicon, requires Xcode build - not in nixpkgs)
      # Pairs with whisper-cpp + openai-whisper (those are in nix-ai home.packages as Nix derivations)
      "whisperkit-cli"
    ]
    # Append formulae required by nix-ai's per-agent modules. Currently:
    # qwen-code (Alibaba's CLI agent — see modules/qwen-code in nix-ai).
    # `lib.unique` deduplicates in case a formula migrates between the
    # static list above and nix-ai's exported list during a transition
    # — `brew bundle` is idempotent but the duplicate noise is worth
    # eliminating at the Nix layer.
    ++ lib.unique agentBrewFormulae;
    casks = [
      # GUI applications (only if not available in nixpkgs)
      #
      # TCC NOTE: Homebrew casks install directly to /Applications/ (real copies,
      # not symlinks to /nix/store), so macOS TCC permissions (camera, mic, screen
      # recording) persist across darwin-rebuild. This is different from nixpkgs
      # apps which require copyApps workaround in home-manager.
      #
      # greedy = true: required for any app that ships a built-in auto-updater.
      # Without this flag, `brew upgrade` silently skips the app because Homebrew
      # assumes the app will update itself. In practice, built-in updaters are
      # unreliable (require the app to be open, can be dismissed, etc.), so greedy
      # ensures updates land deterministically via brew autoupdate.
      # NOTE: ChatGPT and Cursor are in nixpkgs - see home.packages.
      # NOTE: Antigravity and gemini-cli are in homebrew (above).

      # --- Productivity / Communication ---
      {
        name = "obsidian";
        greedy = true;
      } # Knowledge base / note-taking
      {
        name = "shortwave";
        greedy = true;
      } # AI-powered email client
      {
        name = "wispr-flow";
        greedy = true;
      } # AI-powered voice dictation
      {
        name = "voiceink";
        greedy = true;
      } # Voice-to-text app (local whisper)

      # --- Anthropic ---
      {
        name = "claude";
        greedy = true;
      } # Claude desktop app (not in nixpkgs for Darwin)
      {
        name = "claude-code";
        greedy = true;
      } # Claude Code CLI

      # --- OpenAI ---
      # OpenAI Codex CLI (AI coding agent) - migrated from homebrew/core to cask
      # Moved from nixpkgs to match claude/gemini installation pattern
      {
        name = "codex";
        greedy = true;
      }

      # --- Local Inference ---
      # LM Studio: local LLM inference UI + OpenAI-compatible API server
      {
        name = "lm-studio";
        greedy = true;
      }

      # --- Google Gemini ---
      {
        name = "antigravity";
        greedy = true;
      } # Google's AI-powered IDE (Gemini 3) - moved from nixpkgs for Gemini 3.1 Pro support

      # --- API Development ---
      {
        name = "postman";
        greedy = true;
      } # API development environment (moved from nixpkgs — version lag caused schema mismatch)

      # --- OrbStack ---
      # Installed as a Homebrew cask rather than nixpkgs so that:
      #   1. TCC permissions (Docker socket, Linux VM) persist across rebuilds
      #      (nixpkgs installs symlink to /nix/store path which changes on rebuild)
      #   2. greedy = true keeps it current without relying on its built-in updater
      # The programs.orbstack module still manages the APFS data volume; only
      # package.enable is set to false to avoid a conflicting nixpkgs install.
      {
        name = "orbstack";
        greedy = true;
      }

      # --- Microsoft ---
      # Teams is only distributed via Homebrew (not available on Mac App Store).
      {
        name = "microsoft-teams";
        greedy = true;
      }

      # --- Browsers ---
      # Firefox is in nixpkgs (firefox-bin) but installs to /nix/store/<hash>
      # which changes every rebuild — resets macOS TCC grants (camera, mic,
      # screen recording). Cask installs to stable /Applications/Firefox.app.
      {
        name = "firefox";
        greedy = true;
      }

      # --- Office Suite (for Claude document-skills) ---
      # LibreOffice provides the `soffice` CLI that /document-skills:{docx,xlsx,pptx}
      # use to convert Office docs to PDF. nixpkgs does NOT build libreoffice for
      # aarch64-darwin, so homebrew is the correct fallback per "nixpkgs first,
      # then brew" policy. On Linux it ships via nix-home home.packages.
      {
        name = "libreoffice";
        greedy = true;
      }

      # --- Out-of-band server management ---
      # Java Web Start replacement for iDRAC6 vKVM .jnlp launches.
      # iDRAC6 Virtual Console requires NPAPI Java plugin, dropped by all
      # modern browsers (Chrome 2015, Safari, Firefox, Brave). OpenWebStart
      # runs the .jnlp file that the iDRAC web UI downloads on "Launch Virtual
      # Console".
      {
        name = "openwebstart";
        greedy = true;
      }
    ];

    # Mac App Store apps (requires signed into App Store)
    # Find app IDs: mas search <name> or https://github.com/mas-cli/mas
    # Format: "App Name" = app_id;
    masApps = {
      "Toggl Track" = 1291898086; # Time tracking
      "Monarch Money Tweaks" = 6753774259; # Personal finance enhancements
      # NOTE: GoPro Quik (561350520) removed - no longer needed

      # Microsoft 365 bundle (https://apps.apple.com/us/app-bundle/microsoft-365/id1450038993)
      # NOTE: First-time install requires `sudo mas install <id>` due to TTY/sudo constraints
      # Individual apps from the bundle - replaces any non-App Store versions
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Outlook" = 985367838;
      "Microsoft OneNote" = 784801555;
      "OneDrive" = 823766827;
    };
  };

  # (Re)create the brew autoupdate LaunchAgent plist on every darwin-rebuild switch.
  # All logic lives in scripts/configure-brew-autoupdate.sh; this binding only
  # passes the configured interval through as an env var and invokes the script.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    AUTOUPDATE_INTERVAL=${lib.escapeShellArg (toString autoupdateInterval)} \
      ${lib.getExe configureBrewAutoupdateScript} || true
  '';
}
