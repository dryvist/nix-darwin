# Homebrew fallback for packages unavailable or unsuitable in nixpkgs.
# Individual Homebrew package versions cannot be pinned declaratively.

{
  lib,
  nix-ai,
  hostConfig,
  ...
}:

let
  # Server hosts install only serverBrews; activation removes undeclared packages.
  inherit (hostConfig) isServer;

  # Server-only Homebrew packages.
  serverBrews = [
    # Apple container runtime for the GitHub Actions runner VM.
    "container"
  ];

  # Formulae exported by nix-ai modules that require Homebrew.
  agentBrewFormulae = nix-ai.lib.brewFormulae or [ ];

  # AI-tool taps and casks exported by nix-ai.
  agentHomebrewTaps = nix-ai.lib.homebrewTaps or [ ];
  agentHomebrewCasks = nix-ai.lib.homebrewCasks or [ ];

  workstationBrews = [
    # Mac App Store CLI for homebrew.masApps.
    "mas"
    # Apple container runtime.
    "container"

    # AI agent tools available only through Homebrew.
    "block-goose-cli"
    # Apple Silicon speech recognition.
    "whisperkit-cli"
  ]
  # Avoid duplicate formula declarations.
  ++ lib.unique agentBrewFormulae;

  workstationCasks = [
    # Casks install stable /Applications copies, preserving macOS TCC grants.
    # greedy lets Homebrew upgrade apps with built-in updaters.

    # --- Productivity / Communication ---
    {
      name = "obsidian";
      greedy = true;
    } # Knowledge base / note-taking
    # nixpkgs Bitwarden is blocked by an insecure Electron dependency.
    {
      name = "bitwarden";
      greedy = true;
    } # Password manager
    {
      name = "wispr-flow";
      greedy = true;
    } # AI-powered voice dictation
    {
      name = "voiceink";
      greedy = true;
    } # Voice-to-text app (local whisper)
    # GitHub and Linear menu-bar notifications.
    {
      name = "neat";
      greedy = true;
    }

    # --- Anthropic ---
    {
      name = "claude";
      greedy = true;
    } # Claude desktop app

    # --- OpenAI ---
    # ChatGPT desktop app.
    {
      name = "chatgpt";
      greedy = true;
    }
    # Codex desktop app for ChatGPT mobile remote access; separate from the CLI.
    {
      name = "codex-app";
      greedy = true;
    }
    # Codex CLI.
    {
      name = "codex";
      greedy = true;
    }

    # --- Local Inference ---
    # Local LLM inference UI and OpenAI-compatible API server.
    {
      name = "lm-studio";
      greedy = true;
    }

    # --- API Development ---
    {
      name = "postman";
      greedy = true;
    } # API development environment

    # Stable application path preserves TCC grants; the module manages its APFS volume.
    {
      name = "orbstack";
      greedy = true;
    }

    # --- Microsoft ---
    # Teams desktop app.
    {
      name = "microsoft-teams";
      greedy = true;
    }
    # --- Browsers ---
    # Stable application path preserves TCC grants.
    {
      name = "firefox";
      greedy = true;
    }

    # Provides soffice for document conversion on Apple Silicon.
    {
      name = "libreoffice";
      greedy = true;
    }

    # Java Web Start replacement for iDRAC virtual-console files.
    {
      name = "openwebstart";
      greedy = true;
    }
  ]
  ++ agentHomebrewCasks;

  # Mac App Store apps; requires a signed-in App Store account.
  workstationMasApps = {
    "Toggl Track" = 1291898086; # Time tracking
    "Monarch Money Tweaks" = 6753774259; # Personal finance enhancements
    "Windows App" = 1295203466; # Microsoft Remote Desktop / Windows 365 / AVD client
    # Microsoft 365 applications.
    "Microsoft Word" = 462054704;
    "Microsoft Excel" = 462058435;
    "Microsoft PowerPoint" = 462062816;
    "Microsoft Outlook" = 985367838;
    "Microsoft OneNote" = 784801555;
  };
in
{
  homebrew = {
    enable = true;
    onActivation = {
      # Avoid Homebrew index downloads during rebuilds.
      autoUpdate = false;
      # Server hosts remove undeclared packages; workstations keep them.
      cleanup = if isServer then "zap" else "none";
      # Do not upgrade Homebrew packages during rebuilds.
      upgrade = false;
    };
    # AI-tool taps from nix-ai.
    taps = lib.optionals (!isServer) agentHomebrewTaps;
    brews = if isServer then serverBrews else workstationBrews;
    casks = lib.optionals (!isServer) workstationCasks;
    masApps = if isServer then { } else workstationMasApps;
  };
}
