# Homebrew fallback for packages unavailable or unsuitable in nixpkgs.
# Formulae and casks come from the flake-pinned core and cask taps.

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
    # Versioned runtime remains available alongside the Nix-managed Node.js.
    "node@22"

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
    # silently — but only while the machine is attached to a subnet it also
    # talks to. macOS gates same-subnet connections and exempts routed ones, so
    # on a client VLAN the grant is moot. No MDM payload and no tccutil verb
    # exist, so only a human can grant it, and greedy compounds that: each
    # upgrade is a new bundle to TCC, revoking it.
    {
      name = "ghostty";
      greedy = true;
    } # Terminal emulator — needs Full Disk Access + App Management + Local Network

    # --- Productivity / Communication ---
    # nixpkgs trails upstream releases past the 2-week threshold; greedy cask
    # keeps /Applications current and avoids database schema migration mismatch.
    {
      name = "raycast";
      greedy = true;
    } # Productivity launcher (replaces Spotlight)
    {
      name = "slack";
      greedy = true;
    } # Team chat — vendor-signed Electron app, kept current by the cask
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
      name = "granola";
      greedy = true;
    } # AI-powered meeting notes
    {
      name = "claudebar";
      greedy = true;
    } # Claude Code menu bar utility
    {
      name = "neat";
      greedy = true;
    } # Neat device management app

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
    # Teams desktop app. Its .pkg upgrade needs root, so its own updater moves it.
    "microsoft-teams"
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
    "Monarch Money Tweaks" = 6753774259; # Personal finance enhancements
    "Windows App" = 1295203466; # Microsoft Remote Desktop / Windows 365 / AVD client
    "Omi - Smart Meeting Notes" = 6502156163; # AI meeting notes & memory assistant
    # Microsoft 365 applications.
    "Microsoft Word" = 462054704;
    "Microsoft Excel" = 462058435;
    "Microsoft PowerPoint" = 462062816;
    "Microsoft Outlook" = 985367838;
    "Yubico Authenticator" = 1497506650;
    # OneDrive (823766827) is intentionally NOT managed via masApps: its
    # first-time install needs an admin-password TTY, unavailable during a
    # non-interactive `darwin-rebuild switch` ("sudo: a terminal is
    # required"), so brew bundle failed on every rebuild (#1324).
  };
in
{
  homebrew = {
    enable = true;
    onActivation = {
      # Do not let activation resolve formulae or casks from Homebrew's live API.
      # nix-darwin/modules/homebrew.nix:145-162 prepends extraEnv to `brew bundle`.
      extraEnv.HOMEBREW_NO_INSTALL_FROM_API = "1";
      autoUpdate = false;
      inherit (homebrew) cleanup;
      # Rebuild upgrades only to revisions pinned by the core and cask taps.
      upgrade = true;
    };
    # AI-tool taps, formulae, and casks come from nix-ai through the injected
    # profile. Non-AI workstation packages remain local to nix-darwin.
    # The pinned cask tap is listed so `brew bundle cleanup` keeps it; core is implicit.
    taps = [ "homebrew/cask" ] ++ aiHomebrew.taps;
    brews =
      baseBrews ++ aiHomebrew.brews ++ lib.optionals homebrew.enableWorkstationApps workstationBrews;
    casks = aiHomebrew.casks ++ lib.optionals homebrew.enableWorkstationApps workstationCasks;
    masApps = lib.optionalAttrs homebrew.enableWorkstationApps workstationMasApps;
  };

  # Keep interactive Homebrew commands on the same pinned taps as activation.
  environment.variables.HOMEBREW_NO_INSTALL_FROM_API = "1";
}
