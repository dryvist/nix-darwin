# Homebrew fallback for packages unavailable or unsuitable in nixpkgs.
# Individual Homebrew package versions cannot be pinned declaratively.

{
  lib,
  nix-ai,
  hostConfig,
  ...
}:

let
  inherit (hostConfig) homebrew;

  # Packages needed by every host.
  baseBrews = [
    # Apple container runtime for the GitHub Actions runner VM.
    "container"
  ];

  # Formulae exported by nix-ai modules that require Homebrew.
  agentBrewFormulae = nix-ai.lib.brewFormulae or [ ];

  # AI packages come from nix-ai's one capability-to-package mapping.
  agentHomebrewTaps = nix-ai.lib.homebrewTaps or [ ];
  agentHomebrewCasks = nix-ai.lib.homebrewCasksFor homebrew.ai;

  workstationBrews = [
    # Mac App Store CLI for homebrew.masApps.
    "mas"

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

    # --- OpenAI ---
    # ChatGPT desktop app.
    {
      name = "chatgpt";
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
  ];

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
      inherit (homebrew) cleanup;
      # Do not upgrade Homebrew packages during rebuilds.
      upgrade = false;
    };
    # AI-tool taps and casks come from nix-ai through the injected profile.
    taps = agentHomebrewTaps;
    brews = baseBrews ++ lib.optionals homebrew.enableWorkstationApps workstationBrews;
    casks = agentHomebrewCasks ++ lib.optionals homebrew.enableWorkstationApps workstationCasks;
    masApps = lib.optionalAttrs homebrew.enableWorkstationApps workstationMasApps;
  };
}
