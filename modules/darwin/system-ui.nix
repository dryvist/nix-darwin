# System UI Configuration
#
# NSGlobalDomain settings for appearance, text, and behavior.
# Reference: https://nix-darwin.github.io/nix-darwin/manual/options.html

{ lib, ... }:
{
  system.defaults = {
    # --- NSGlobalDomain Settings ---
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleShowScrollBars = "Automatic";

      # Text & Typing
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticInlinePredictionEnabled = true;

      # Windows & Dialogs
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDocumentSaveNewDocumentsToCloud = false;

      # Animations
      NSAutomaticWindowAnimationsEnabled = true;
      NSScrollAnimationEnabled = true;
      NSUseAnimatedFocusRing = true;

      # Finder Sidebar - Icon size: 1=small, 2=medium, 3=large
      NSTableViewDefaultSizeMode = 1;

      # Language & Region - Imperial system
      AppleTemperatureUnit = "Fahrenheit";
      AppleMeasurementUnits = "Inches";
      AppleMetricUnits = 0;
      AppleICUForce24HourTime = true;

      # Note: NSStatusItemSpacing and NSStatusItemSelectionPadding are set via
      # activation script (requires -currentHost flag to work properly)
    };

    # --- Menu Bar Clock ---
    menuExtraClock = {
      ShowDate = 1; # 0 = When space allows, 1 = Always, 2 = Never
      ShowDayOfWeek = true;
      ShowSeconds = true;
      Show24Hour = true; # Also set via AppleICUForce24HourTime
      IsAnalog = false; # false = digital, true = analog
    };

    # --- Login Window ---
    loginwindow = {
      GuestEnabled = false;
      SHOWFULLNAME = false;
    };

    # --- Screensaver & Lock ---
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0; # 0 = immediately
    };

    # --- Screenshots ---
    screencapture = {
      # location = "/Users/${userConfig.user.name}/Screenshots";
      type = "png"; # png, jpg, gif, pdf, tiff
      disable-shadow = true;
      include-date = true;
    };

    # --- Control Center (Menu Bar) ---
    controlcenter = {
      BatteryShowPercentage = true;
      Bluetooth = true;
      Sound = true;
      Display = true;
      FocusModes = true;
      NowPlaying = true;
    };

    # --- Custom User Preferences ---
    # Settings not exposed as first-class nix-darwin options
    CustomUserPreferences = {
      "com.apple.menuextra.clock" = {
        # Custom date/time format (overrides menuExtraClock display settings)
        # menuExtraClock controls WHICH elements show; DateFormat controls HOW they display
        DateFormat = "yyyy-MM-dd HH:mm:ss"; # ISO 8601-like format (space separator)
        FlashDateSeparators = false; # Don't blink separators
      };
    };
  };

  # --- Activation Scripts - Menu Bar Spacing ---
  # Must use -currentHost flag (nix-darwin system.defaults cannot write the
  # ByHost domain). Changes take effect on the next logout/login.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # NOTE: Follows CRITICAL RULES from docs/ACTIVATION-SCRIPTS-RULES.md:
    #   * NEVER use 'set -e' - errors must not abort activation
    #   * All errors logged as warnings, not fatal
    #   * Must reach /run/current-system symlink update

    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Applying menu bar spacing settings (compact mode)..."

    if defaults -currentHost write -globalDomain NSStatusItemSpacing -int 4; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Menu bar icon spacing set to 4 (compact)"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to set NSStatusItemSpacing to 4 - check defaults permissions" >&2
    fi

    if defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 8; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Menu bar icon padding set to 8 (compact)"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to set NSStatusItemSelectionPadding to 8 - check defaults permissions" >&2
    fi
  '';
}
