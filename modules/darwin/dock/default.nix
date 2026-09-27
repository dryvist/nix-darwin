# Dock Configuration
#
# Comprehensive Dock settings for macOS via nix-darwin.
# All options are listed for visibility, even defaults.
#
# Reference: https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/defaults/dock.nix

_:

{
  imports = [ ./persistent-apps.nix ];

  system.defaults.dock = {
    # ==========================================================================
    # Dock Appearance
    # ==========================================================================

    # Size of dock icons (in pixels)
    # Default: 64, Your preference: 64 (clean number)
    tilesize = 64;

    # Enable icon magnification on hover
    # Default: false
    magnification = true;

    # Magnified icon size (16-128 pixels)
    # Default: 128
    largesize = 80;

    # Dock position on screen: "bottom", "left", or "right"
    # Default: "bottom"
    orientation = "left";

    # ==========================================================================
    # Dock Behavior
    # ==========================================================================

    # Automatically hide and show the Dock
    # Default: false
    autohide = false;

    # Delay before Dock shows when hidden (seconds)
    # Default: 0.24
    # Only applies when autohide = true
    autohide-delay = 0.0;

    # Animation speed for hide/show (seconds)
    # Default: 1.0
    # Lower = faster animation
    autohide-time-modifier = 0.15;

    # Animate opening applications (bounce effect)
    # Default: true
    launchanim = true;

    # Show indicator dots for running applications
    # Default: true
    show-process-indicators = true;

    # Show recent applications section in Dock
    # Default: true
    # Disabled: an ad-hoc app shows only while running and leaves no tile
    # behind after it quits.
    show-recents = false;

    # Minimize windows into their application icon
    # Default: false
    minimize-to-application = true;

    # Window minimize animation: "genie", "suck", or "scale"
    # Default: "genie"
    mineffect = "scale";

    # Make hidden app icons translucent
    # Default: false
    showhidden = true;

    # Show only open applications (hide persistent apps)
    # Default: false
    static-only = false;

    # ==========================================================================
    # Spaces & Mission Control
    # ==========================================================================

    # Automatically rearrange Spaces based on most recent use
    # Default: true
    # false = keep spaces in fixed order
    mru-spaces = false;

    # Group windows by application in Mission Control
    # Default: true
    expose-group-apps = true;

    # Mission Control animation duration (seconds)
    # Default: not set (uses system default)
    # expose-animation-duration = 0.15;

    # ==========================================================================
    # Trackpad Gestures (Dock-related)
    # ==========================================================================

    # Four-finger spread to show Desktop
    showDesktopGestureEnabled = true;

    # Four-finger pinch to show Launchpad
    showLaunchpadGestureEnabled = true;

    # Three-finger swipe up for Mission Control
    showMissionControlGestureEnabled = true;

    # Three-finger swipe down for App Exposé
    showAppExposeGestureEnabled = true;

    # ==========================================================================
    # Hot Corners
    # ==========================================================================
    #
    # Action values:
    #   1  = Disabled
    #   2  = Mission Control
    #   3  = Application Windows (App Exposé)
    #   4  = Desktop
    #   5  = Start Screen Saver
    #   6  = Disable Screen Saver
    #   10 = Put Display to Sleep
    #   11 = Launchpad
    #   12 = Notification Center
    #   13 = Lock Screen
    #   14 = Quick Note
    #
    # Your current configuration:

    # Top-left corner: Mission Control
    wvous-tl-corner = 2;

    # Top-right corner: Notification Center
    wvous-tr-corner = 12;

    # Bottom-left corner: Application Windows (App Exposé)
    wvous-bl-corner = 3;

    # Bottom-right corner: Quick Note
    wvous-br-corner = 14;

    # ==========================================================================
    # Advanced Options
    # ==========================================================================

    # Display app switcher on all displays
    # Default: false (only main display)
    # appswitcher-all-displays = false;

    # Scroll up on Dock icon to show all windows in that Space
    # Default: true
    scroll-to-open = true;

    # Spring loading for Dock items (drag files over apps)
    # Default: false
    enable-spring-load-actions-on-all-items = true;

    # Highlight hover effect for stack grid view
    # Default: false
    mouse-over-hilite-stack = true;

    # Hold Shift for slow-motion minimize animation
    # Default: false
    # slow-motion-allowed = false;
  };
}
