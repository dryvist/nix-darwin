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

_:

let
  userConfig = import ../../../lib/user-config.nix;
  inherit (userConfig.user) homeDir;
in
{
  system.defaults.dock = {
    # ========================================================================
    # Left side of Dock (before separator) - Main apps
    # ========================================================================
    persistent-apps = [
      # Time & Tasks
      "/System/Applications/Clock.app"
      "/System/Applications/Reminders.app"
      "/System/Applications/Calendar.app"
      "/Applications/Toggl Track.app"

      # Knowledge & Notes (after Toggl)
      "/Applications/Obsidian.app"

      # Development & Tools (after Toggl)
      # /Applications, not Home Manager Apps: Ghostty moved to a greedy Homebrew
      # cask on 2026-07-29 so its TCC grants survive (see modules/darwin/homebrew.nix).
      # A Dock entry pointing at the old copyApps path would silently resolve to
      # a bundle that activation no longer writes.
      "/Applications/Ghostty.app"
      "${homeDir}/Applications/Home Manager Apps/Visual Studio Code.app"

      # Communication
      "/System/Applications/Mail.app" # Apple Mail (system app)
      "/Applications/Microsoft Outlook.app"
      "/Applications/Microsoft Teams.app"
      "/Applications/Slack.app"
      "/Applications/zoom.us.app" # Manual install - now at system level
      "/System/Applications/Messages.app"

      # AI Assistants
      "/Applications/Claude.app" # Anthropic Claude desktop app (homebrew cask)
      "${homeDir}/Applications/Gemini.app" # Google Gemini AI assistant
      "/Applications/Antigravity.app" # Google Antigravity 2.0 agent command center
      "/Applications/Antigravity IDE.app" # Google Antigravity IDE

      # Browsers
      "/Applications/Safari.app"
      "/Applications/Brave Browser.app"

      # Remote Desktop
      "/Applications/Windows App.app"

      # NOTE: Additional AI tools (ChatGPT, Cursor) can be found in
      # ~/Applications/Home Manager Apps/, but they are not pinned to the Dock.
      # NOTE: RapidAPI, Postman, and Bitwarden removed from dock per #438
    ];

    # ========================================================================
    # Right side of Dock (after separator) - Folders & utilities
    # ========================================================================
    # No persistent folders configured.
    # Recent apps will appear here if show-recents is enabled.
    persistent-others = [ ];
  };
}
