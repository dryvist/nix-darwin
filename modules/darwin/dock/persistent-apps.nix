# Dock Persistent Apps
#
# Apps appear in the Dock in this exact order.
# Manual Dock changes WILL BE OVERWRITTEN on rebuild.
#
# Each entry names the provider that installs it (see lib/dock-apps.nix), and an
# assertion checks that the provider is declared on the host and installs to
# the entry's path, so a provider move cannot leave a stale Dock path behind.
#
# App locations:
#   - System apps: /System/Applications/
#   - Homebrew casks and Mac App Store apps: /Applications/
#   - Home Manager apps (copyApps): ~/Applications/Home Manager Apps/
#   - Manual installs (outside this configuration): any path, with a reason
#
# NOTE on TCC-sensitive apps. copyApps (migrated from mac-app-util trampolines)
# gives a stable PATH, which is necessary but NOT sufficient: activation replaces
# the bundle wholesale, and a delete-and-recreate reads as a new bundle to TCC
# even at an unchanged path. Ghostty — the terminal every agent session and every
# darwin-rebuild runs inside — therefore moved to a greedy Homebrew cask on
# 2026-07-29, which Homebrew upgrades in place. VS Code remains on copyApps; if
# its grants prove to lapse the same way, it should follow.

{
  config,
  lib,
  hostConfig,
  ...
}:

let
  userConfig = import ../../../lib/user-config.nix;
  inherit (userConfig.user) homeDir;

  inherit (hostConfig.homebrew) enableWorkstationApps;

  dockApps = import ../../../lib/dock-apps.nix { inherit lib; };

  app = path: via: { inherit path via; };
  system = {
    system = true;
  };

  # Server hosts keep the same tiles, but only workstations declare these
  # providers, so on a server the app is recorded as installed outside this
  # configuration.
  onWorkstation =
    via:
    if enableWorkstationApps then
      via
    else
      { manual = "this configuration installs it on workstation hosts only"; };

  hmApps = "${homeDir}/Applications/Home Manager Apps";

  # Uses native Nix conditional expressions (`lib.optionals`) driven by
  # `hostConfig` capabilities to include GUI applications only on hosts where
  # they are installed (workstations), while keeping server Docks clean.
  apps = [
    # System Settings & Time (system apps present on all hosts)
    (app "/System/Applications/System Settings.app" system)
    (app "/System/Applications/Clock.app" system)

    # Tasks & Scheduling (system apps present on all hosts)
    (app "/System/Applications/Reminders.app" system)
    (app "/System/Applications/Calendar.app" system)
  ]
  ++ lib.optionals enableWorkstationApps [
    # Communication (Slack before Teams)
    (app "/Applications/Slack.app" { cask = "slack"; })
    (app "/System/Applications/Messages.app" system)
    (app "/Applications/Microsoft Teams.app" { cask = "microsoft-teams"; })
  ]
  ++ [
    # Primary Browser (present on all hosts)
    (app "/Applications/Safari.app" system)
  ]
  ++ lib.optionals enableWorkstationApps [
    # Secondary Browser
    (app "/Applications/Brave Browser.app" { cask = "brave-browser"; })

    # Knowledge Base & Notes
    (app "${hmApps}/Obsidian.app" { nixpkgs = "obsidian"; })
  ]
  ++ [
    # Voice Intelligence (all hosts show the tile)
    (app "/Applications/Wispr Flow.app" (onWorkstation {
      cask = "wispr-flow";
    }))
  ]
  ++ lib.optionals enableWorkstationApps [
    # Meeting Assistants (workstation only)
    (app "/Applications/Foresight.app" {
      manual = "vendor download; no Homebrew cask or Mac App Store listing";
    })
    (app "/Applications/Omi.app" { mas = 6502156163; })
    (app "/Applications/Granola.app" { cask = "granola"; })
  ]
  ++ [
    # Terminal (all hosts show the tile)
    (app "/Applications/Ghostty.app" (onWorkstation {
      cask = "ghostty";
    }))
  ]
  ++ lib.optionals enableWorkstationApps [
    # Development & Editors
    (app "${hmApps}/Visual Studio Code.app" { nixpkgs = "vscode"; })
  ]
  ++ [
    # AI & API Tools (all hosts show the tiles; ChatGPT removed, Codex kept)
    (app "/Applications/ProxMan.app" {
      manual = "vendor download; no Homebrew cask or Mac App Store listing";
    })
    (app "/Applications/Claude.app" (onWorkstation {
      cask = "claude";
    }))
    (app "${homeDir}/Applications/Gemini.app" {
      manual = "vendor download; the Homebrew gemini cask installs a different app bundle";
    })
    (app "/Applications/Codex.app" (onWorkstation {
      cask = "codex-app";
    }))
  ]
  ++ lib.optionals enableWorkstationApps [
    # Remote Desktop (positioned at the very end of app icons)
    (app "/Applications/Windows App.app" { mas = 1295203466; })
  ];

  declared = {
    inherit homeDir;
    casks = map (cask: cask.name or cask) config.homebrew.casks;
    masIds = lib.attrValues config.homebrew.masApps;
    pnames = lib.concatMap (user: map (package: package.pname or "") user.home.packages) (
      lib.attrValues (config.home-manager.users or { })
    );
  };
  problems = dockApps.problems declared apps;
in
{
  assertions = [
    {
      assertion = problems == [ ];
      message = ''
        dock-apps: these Dock entries have no matching provider
        (modules/darwin/dock/persistent-apps.nix):

        ${lib.concatStringsSep "\n" problems}

        Declare the provider on this host, fix the entry's path, or mark the
        entry manual with a reason.
      '';
    }
  ];

  system.defaults.dock = {
    # ========================================================================
    # Left side of Dock (before separator) - Main apps
    # ========================================================================
    persistent-apps =
      map (entry: entry.path) apps
      # Visual Spacer: separates permanent Dock apps from dynamic running apps
      ++ lib.optional enableWorkstationApps {
        spacer = {
          small = false;
        };
      };

    # ========================================================================
    # Right side of Dock (after separator) - Folders & utilities
    # ========================================================================
    # No persistent folders configured.
    persistent-others = [ ];
  };
}
