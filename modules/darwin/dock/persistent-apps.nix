# Dock Persistent Apps
#
# Apps appear in the Dock in this exact order.
# Manual Dock changes WILL BE OVERWRITTEN on rebuild.
#
# App locations:
#   - System apps: /System/Applications/
#   - Nix system packages: /Applications/Nix Apps/
#   - Home Manager apps (copyApps): ~/Applications/Home Manager Apps/
#   - Manual installs: /Applications/
#   - User apps: ~/Applications/
#
# NOTE on TCC-sensitive apps. copyApps (migrated from mac-app-util trampolines)
# gives a stable PATH, which is necessary but NOT sufficient: activation replaces
# the bundle wholesale, and a delete-and-recreate reads as a new bundle to TCC
# even at an unchanged path. Ghostty — the terminal every agent session and every
# darwin-rebuild runs inside — therefore moved to a greedy Homebrew cask on
# 2026-07-29, which Homebrew upgrades in place. VS Code remains on copyApps; if
# its grants prove to lapse the same way, it should follow.

{ lib, hostConfig, ... }:

let
  userConfig = import ../../../lib/user-config.nix;
  inherit (userConfig.user) homeDir;

  inherit (hostConfig.homebrew) enableWorkstationApps;
in
{
  system.defaults.dock = {
    # ========================================================================
    # Left side of Dock (before separator) - Main apps
    # ========================================================================
    # Uses native Nix conditional expressions (`lib.optionals`) driven by
    # `hostConfig` capabilities to include GUI applications only on hosts where
    # they are installed (workstations), while keeping server Docks clean.
    persistent-apps = [
      # System settings & time (system apps present on all hosts)
      "/System/Applications/System Settings.app"
      "/System/Applications/Clock.app"
      "/System/Applications/Reminders.app"
      "/System/Applications/Calendar.app"
    ]
    ++ lib.optionals enableWorkstationApps [
      # Communication before Safari (Slack before Teams)
      "/Applications/Slack.app"
      "/System/Applications/Messages.app"
      "/Applications/Microsoft Teams.app"
    ]
    ++ [
      "/Applications/Safari.app"
    ]
    ++ lib.optionals enableWorkstationApps [
      # Browsers, Knowledge, Voice & Meeting tools
      "/Applications/Brave Browser.app"
      "/Applications/Obsidian.app"
      "/Applications/Foresight.app"
      "/Applications/Omi.app"
      "/Applications/Wispr Flow.app"
      "/Applications/Granola.app"
    ]
    ++ [
      # Terminal (present on all hosts)
      "/Applications/Ghostty.app"
    ]
    ++ lib.optionals enableWorkstationApps [
      # Development & Tools
      "${homeDir}/Applications/Home Manager Apps/Visual Studio Code.app"
    ]
    ++ [
      # AI & API tools (present on all hosts; ChatGPT removed, Codex kept)
      "/Applications/ProxMan.app"
      "/Applications/Claude.app"
      "${homeDir}/Applications/Gemini.app"
      "/Applications/Codex.app"
    ]
    ++ lib.optionals enableWorkstationApps [
      # Windows App at the very end
      "/Applications/Windows App.app"
      # Spacer after Windows App to separate true dock apps from recently opened apps
      {
        spacer = {
          small = false;
        };
      }
    ];

    # ========================================================================
    # Right side of Dock (after separator) - Folders & utilities
    # ========================================================================
    # No persistent folders configured.
    persistent-others = [ ];
  };
}
