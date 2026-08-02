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

  # AI package identities and package types come from nix-ai. This module only
  # passes the host's single default-off capability set.
  aiHomebrew = nix-ai.lib.homebrewFor homebrew.ai;

  workstationBrews = [
    # Mac App Store CLI for homebrew.masApps.
    "mas"

    # Apple Silicon speech recognition.
    "whisperkit-cli"
  ];

  workstationCasks = [
    # Casks install stable /Applications copies, preserving macOS TCC grants.
    # greedy lets Homebrew upgrade apps with built-in updaters.

    # --- Terminal ---
    # THE most TCC-sensitive app here: every agent session and every
    # darwin-rebuild runs inside it, so a lapsed Full Disk Access grant does not
    # merely annoy — it stops the machine being manageable until a human
    # re-grants it. Moved off nixpkgs copyApps on 2026-07-29 because activation
    # replaces the bundle wholesale, and a delete-and-recreate is a new bundle to
    # TCC even at a stable path and even for a Developer-ID-signed app.
    # Local Network is a THIRD grant this app needs, and the one that fails
    # silently. macOS gates same-subnet connections, exempts routed ones, and
    # attaches the verdict to the responsible GUI app. Under this terminal a nix
    # python cannot reach a same-subnet host that /usr/bin/curl reaches on the
    # same port — reads as an outage, every hand-run probe says otherwise.
    # No MDM payload and no tccutil verb exist, so only a human can grant it.
    # greedy compounds it: each upgrade is a new bundle to TCC, revoking it.
    # Terminal.app is exempt by design — see docs/MACOS-LOCAL-NETWORK-TCC.md.
    {
      name = "ghostty";
      greedy = true;
    } # Terminal emulator — needs Full Disk Access + App Management + Local Network

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
      name = "superwhisper";
      greedy = true;
    } # Dictation with LLM reformatting
    {
      name = "voiceink";
      greedy = true;
    } # Voice-to-text app (local whisper)
    # GitHub and Linear menu-bar notifications.
    {
      name = "neat";
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

    # Image editor. nixpkgs gimp is Linux-only (no darwin meta.platforms
    # entry) — cask is the only working path here.
    {
      name = "gimp";
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
    # AI-tool taps, formulae, and casks come from nix-ai through the injected
    # profile. Non-AI workstation packages remain local to nix-darwin.
    inherit (aiHomebrew) taps;
    brews =
      baseBrews ++ aiHomebrew.brews ++ lib.optionals homebrew.enableWorkstationApps workstationBrews;
    casks = aiHomebrew.casks ++ lib.optionals homebrew.enableWorkstationApps workstationCasks;
    masApps = lib.optionalAttrs homebrew.enableWorkstationApps workstationMasApps;
  };
}
