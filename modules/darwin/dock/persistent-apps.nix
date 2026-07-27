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
# NOTE: TCC-sensitive apps (Ghostty, VS Code) use copyApps (migrated from
# mac-app-util trampolines) for stable paths that persist macOS TCC
# permissions across darwin-rebuild.

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
      "${homeDir}/Applications/Home Manager Apps/Ghostty.app"
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
