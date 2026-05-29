# Finder Configuration
#
# Comprehensive Finder settings for macOS via nix-darwin.
# All options listed for visibility - tune these to make Finder less annoying.
#
# Reference: https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/defaults/finder.nix

_: {
  system.defaults.finder = {
    # ==========================================================================
    # File Visibility
    # ==========================================================================

    # Show hidden files (dotfiles) in Finder
    # Default: false
    # Power users: true
    AppleShowAllFiles = true;

    # Show all file extensions
    # Default: false
    AppleShowAllExtensions = true;

    # Warn when changing file extension
    # Default: true
    FXEnableExtensionChangeWarning = false;

    # ==========================================================================
    # Window Appearance
    # ==========================================================================

    # Show status bar at bottom (item count, disk space)
    # Default: false
    ShowStatusBar = true;

    # Show path breadcrumb bar
    # Default: false
    ShowPathbar = true;

    # Show full POSIX path in window title
    # Default: false
    # Example: "${GIT_HOME}/project" instead of "project"
    _FXShowPosixPathInTitle = true;

    # Default view style for new windows
    # Options: "icnv" (Icon), "Nlsv" (List), "clmv" (Column), "Flwv" (Gallery)
    # Default: "icnv"
    FXPreferredViewStyle = "Nlsv";

    # ==========================================================================
    # Sorting & Organization
    # ==========================================================================

    # Keep folders on top when sorting by name
    # Default: false
    _FXSortFoldersFirst = true;

    # Keep folders on top on Desktop
    # Default: false
    _FXSortFoldersFirstOnDesktop = true;

    # ==========================================================================
    # Search Behavior
    # ==========================================================================

    # Default search scope
    # Options:
    #   "SCev" = Search This Mac (everywhere)
    #   "SCcf" = Search Current Folder
    #   "SCsp" = Use Previous Search Scope
    # Default: "SCev"
    # Your preference: search current folder
    FXDefaultSearchScope = "SCcf";

    # ==========================================================================
    # New Window Behavior
    # ==========================================================================

    # What to show in new Finder windows
    # Options: "Computer", "OS volume", "Home", "Desktop", "Documents",
    #          "Recents", "iCloud Drive", "Other"
    # Default: "Home"
    NewWindowTarget = "Home";

    # Path for "Other" new window target
    # Only used when NewWindowTarget = "Other"
    # NewWindowTargetPath = "file:///Users/${userConfig.user.name}/";

    # ==========================================================================
    # Desktop Icons
    # ==========================================================================

    # Show icons on desktop at all
    # Default: true
    CreateDesktop = true;

    # Show external hard drives on Desktop
    # Default: true
    ShowExternalHardDrivesOnDesktop = true;

    # Show internal hard drives on Desktop
    # Default: false
    ShowHardDrivesOnDesktop = false;

    # Show mounted servers on Desktop
    # Default: false
    ShowMountedServersOnDesktop = false;

    # Show removable media (USB drives) on Desktop
    # Default: true
    ShowRemovableMediaOnDesktop = true;

    # ==========================================================================
    # Trash
    # ==========================================================================

    # Automatically remove items from Trash after 30 days
    # Default: false
    FXRemoveOldTrashItems = true;

    # ==========================================================================
    # Finder Application
    # ==========================================================================

    # Allow quitting Finder via Cmd-Q
    # Default: false
    # Quitting Finder hides Desktop icons
    QuitMenuItem = false;
  };

  # ==========================================================================
  # Additional Finder Settings via CustomUserPreferences
  # ==========================================================================
  # These settings aren't exposed as first-class nix-darwin options,
  # but can be set via the CustomUserPreferences escape hatch.

  system.defaults.CustomUserPreferences = {
    "com.apple.finder" = {
      # Open new windows as tabs instead of new windows
      FinderSpawnTab = true;

      # Disable the "Are you sure you want to open this application?" dialog
      # WarnOnApplicationOpen = false;

      # Column view settings
      # ColumnShowIcons = true;
    };

    "com.apple.desktopservices" = {
      # Disable .DS_Store file creation on network volumes
      DSDontWriteNetworkStores = true;

      # Disable .DS_Store file creation on USB volumes
      DSDontWriteUSBStores = true;
    };

    # Disable personalized ads (privacy)
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
    };
  };
}
