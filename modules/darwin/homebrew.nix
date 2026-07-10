# Homebrew Configuration
#
# Homebrew is a FALLBACK ONLY for packages not in nixpkgs or severely outdated.
# Prefer nixpkgs for everything - only use homebrew when absolutely necessary.
#
# == Update Philosophy ==
#
# Our configuration:
#   - onActivation.autoUpdate = false  → Keeps rebuilds fast (no 45MB index download)
#   - onActivation.upgrade = false     → Rebuilds don't run brew upgrade
#   - Passive auto-update: Enabled     → >5 minutes trigger on command invocation
#
# == How Packages Get Updated ==
#
# 1. MANUAL: Run `brew update && brew upgrade --greedy` for updates
# 2. RENOVATE: Cannot track homebrew versions (no version info in this config)
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
  nix-ai,
  hostConfig,
  ...
}:

let
  # Server-class hosts are LEAN BY CONSTRUCTION: the entire workstation
  # catalog below (GUI casks, Mac App Store apps, desktop AI tools) is
  # workstation-only. A server's Homebrew surface is exactly the brews in
  # `serverBrews` — nothing else — and cleanup = "zap" makes activation
  # actively UNINSTALL anything not declared, so drift cannot accumulate.
  # (Hit on jevans-ms 2026-07-02: the ungated list installed the laptop's
  # desktop apps on the headless LLM server.)
  # (isServer is normalized once in flake.nix mkHost.)
  inherit (hostConfig) isServer;

  # The only Homebrew packages a server host needs. Add here ONLY with a
  # written justification; everything else belongs in nixpkgs or nowhere.
  serverBrews = [
    # Apple container CLI/runtime — runs the ephemeral GitHub Actions
    # runner VM (modules/darwin/apps/github-runner-container.nix).
    # Homebrew because nixpkgs lags by a major release.
    "container"
  ];

  # Brew formulae required by per-agent nix-ai modules whose preferred
  # install source is Homebrew (e.g. programs.qwen-code with
  # installVia = "brew"). The list is owned by the agent's module in
  # nix-ai and exported as a flake output, so each module stays
  # self-contained. See nix-ai/docs/architecture/per-agent-flakes.md.
  agentBrewFormulae = nix-ai.lib.brewFormulae or [ ];

  # AI-tool taps and casks owned by nix-ai (lib/homebrew.nix).
  # Trust is handled declaratively by nix-ai's home-manager module via
  # ~/.homebrew/trust.json — no brew trust command needed.
  agentHomebrewTaps = nix-ai.lib.homebrewTaps or [ ];
  agentHomebrewCasks = nix-ai.lib.homebrewCasks or [ ];

  workstationBrews = [
    # Mac App Store CLI — required by homebrew.masApps below.
    "mas"
    # Apple container CLI/runtime. Homebrew tracks current upstream while
    # nixpkgs lags by a major release.
    "container"

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

  workstationCasks = [
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
    # ensures updates land deterministically when running brew upgrade.
    # NOTE: Cursor is in nixpkgs - see home.packages. ChatGPT is a cask below.
    # NOTE: AI-tool casks (claude-code@latest, antigravity suite) are appended
    # below from nix-ai.lib.homebrewCasks (source: nix-ai/lib/homebrew.nix).

    # --- Productivity / Communication ---
    {
      name = "obsidian";
      greedy = true;
    } # Knowledge base / note-taking
    # Bitwarden desktop password manager. Cask, NOT nixpkgs: the nixpkgs
    # `bitwarden-desktop` build pins `electron_39`, which is now EOL and
    # flagged insecure, so `darwin-rebuild` refuses to evaluate it. Bitwarden
    # upstream still pins electron_39 even on its latest release, so bumping
    # nixpkgs does not help. This cask is Bitwarden's own signed build
    # (independent of nixpkgs' from-source electron), so it sidesteps the EOL
    # flag and stays current via greedy auto-update. Moved here from
    # modules/darwin/common.nix systemPackages.
    {
      name = "bitwarden";
      greedy = true;
    } # Password manager desktop app (ex-nixpkgs; EOL electron_39)
    {
      name = "wispr-flow";
      greedy = true;
    } # AI-powered voice dictation
    {
      name = "voiceink";
      greedy = true;
    } # Voice-to-text app (local whisper)
    # Neat: GitHub + Linear notifications in the menu bar. Not in nixpkgs
    # (proprietary macOS-only app from neat.run); greedy so its built-in
    # auto-updater does not cause brew upgrade to skip it.
    {
      name = "neat";
      greedy = true;
    } # GitHub/Linear menu-bar notifications

    # --- Anthropic ---
    {
      name = "claude";
      greedy = true;
    } # Claude desktop app (not in nixpkgs for Darwin)
    # claude-code@latest moved to nix-ai/lib/homebrew.nix

    # --- OpenAI ---
    # ChatGPT desktop app. Cask, NOT nixpkgs: nixpkgs lags OpenAI's ~weekly
    # releases by months and a read-only store app cannot self-update.
    # greedy mirrors the `claude` desktop pattern so brew upgrade keeps it
    # current. Moved from home.packages (nixpkgs chatgpt).
    {
      name = "chatgpt";
      greedy = true;
    } # ChatGPT desktop app (ex-nixpkgs; version lag + no self-update)
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

    # antigravity suite moved to nix-ai/lib/homebrew.nix

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
    # PowerShell migrated to the nix-devenv `windows` dev shell (stable pwsh
    # from nixpkgs): `nix develop github:dryvist/nix-devenv?dir=shells/windows`.
    # Moved off the always-on cask per nix-package-placement (project-scoped
    # toolchain → nix-devenv). cleanup="none", so the previously-installed
    # cask is left in place; run `brew uninstall --cask powershell@preview`
    # to remove it.

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
  ]
  ++ agentHomebrewCasks; # AI-tool casks from nix-ai/lib/homebrew.nix

  # Mac App Store apps (requires signed into App Store)
  # Find app IDs: mas search <name> or https://github.com/mas-cli/mas
  # Format: "App Name" = app_id;
  workstationMasApps = {
    "Toggl Track" = 1291898086; # Time tracking
    "Monarch Money Tweaks" = 6753774259; # Personal finance enhancements
    "Windows App" = 1295203466; # Microsoft Remote Desktop / Windows 365 / AVD client
    # NOTE: GoPro Quik (561350520) removed - no longer needed

    # Microsoft 365 bundle (https://apps.apple.com/us/app-bundle/microsoft-365/id1450038993)
    # NOTE: First-time install requires `sudo mas install <id>` due to TTY/sudo constraints
    # Individual apps from the bundle - replaces any non-App Store versions
    "Microsoft Word" = 462054704;
    "Microsoft Excel" = 462058435;
    "Microsoft PowerPoint" = 462062816;
    "Microsoft Outlook" = 985367838;
    "Microsoft OneNote" = 784801555;
    # OneDrive (823766827) is intentionally NOT managed via masApps: its
    # first-time `mas install` needs an admin-password TTY, which is
    # unavailable during non-interactive `darwin-rebuild switch`
    # ("sudo: a terminal is required"), failing brew bundle on every rebuild.
  };
in
{
  homebrew = {
    enable = true;
    onActivation = {
      # Don't download 45MB index on every rebuild - keeps rebuilds fast and deterministic.
      # Homebrew's passive auto-update still works (triggers on command invocation after >5 minutes).
      autoUpdate = false;
      # Workstation: "none" — don't remove manually installed packages.
      # Server: "zap" — the Brewfile is the complete allowed set; activation
      # uninstalls (and zaps caches/preferences of) anything outside it.
      cleanup = if isServer then "zap" else "none";
      # Upgrades are not run during darwin-rebuild to keep rebuilds fast.
      # Run `brew upgrade --greedy` manually for updates.
      upgrade = false;
    };
    # AI-tool taps declared in nix-ai/lib/homebrew.nix. The former "aws/tap"
    # tap was removed — nothing was installed from it (audit 2026-06-30).
    taps = lib.optionals (!isServer) agentHomebrewTaps;
    brews = if isServer then serverBrews else workstationBrews;
    casks = lib.optionals (!isServer) workstationCasks;
    masApps = if isServer then { } else workstationMasApps;
  };
}
