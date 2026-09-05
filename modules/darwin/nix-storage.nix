{ lib, pkgs, ... }:

let
  userConfig = import ../../lib/user-config.nix;
in
{
  # ============================================================================
  # Determinate Nix Integration
  # ============================================================================
  # Official module — automatically sets nix.enable = false and manages
  # /etc/nix/nix.custom.conf + /etc/determinate/config.json declaratively.
  determinateNix = {
    enable = true;

    # ============================================================================
    # Nix Store Settings (written to /etc/nix/nix.custom.conf)
    # ============================================================================
    customSettings = {
      # Hard-link identical files in the store to save disk space
      # Runs during every build — slight build-time cost for ongoing savings
      # Default: false
      auto-optimise-store = true;

      # Minimum free disk space (bytes) before Nix triggers GC during builds
      # 1 GiB — if free space drops below this mid-build, Nix GCs until max-free
      # Default: 0 (disabled)
      min-free = 1073741824;

      # Target free disk space (bytes) after min-free triggers GC
      # 5 GiB — Nix collects garbage until this much space is free
      # Default: unlimited
      max-free = 5368709120;

      # Allow the primary user to use flake-level nixConfig (extra-substituters, etc.)
      # Security: equivalent to root for Nix store operations — appropriate for
      # single-user macOS workstation where the primary user already has sudo
      # The automation account is listed for the unprivileged
      # `darwin-rebuild build` it runs before its own switch; under sudo it is
      # already root and already trusted.
      trusted-users = [
        "root"
        userConfig.user.name
        userConfig.agentUser.name
      ];

      # devenv binary cache — used by nix-ai devShells, avoids building from source
      extra-substituters = [ "https://devenv.cachix.org" ];
      extra-trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];

      # -- Defaults left commented for awareness --
      # max-jobs = "auto";           # Parallel build jobs (set by Determinate Nix)
      # keep-build-log = true;       # Retain build logs for debugging
      # keep-derivations = true;     # Keep .drv files (needed for nix log)
      # keep-outputs = true;         # Keep outputs reachable from installed packages
    };

    # ============================================================================
    # Determinate Nixd Garbage Collector
    # ============================================================================
    # Built-in to determinate-nixd — no launchd daemon needed.
    # Automatic mode targets: 30GB minimum free, 5-20% steady-state free,
    # urgent cleanup below 5% free.
    determinateNixd = {
      garbageCollector = {
        # "automatic" — determinate-nixd manages GC in the background
        # "disabled" — no automatic GC (manual only: nix-collect-garbage -d)
        strategy = "automatic";
      };
    };
  };

  # ============================================================================
  # Scheduled Generation Pruning (LaunchDaemon)
  # ============================================================================
  # determinateNixd's reactive GC only collects *unreferenced* store paths —
  # it does NOT delete old profile generations. Profile generation symlinks are
  # GC roots, so every old generation keeps its entire system closure alive.
  # nix.gc.automatic cannot be used because Determinate Nix sets nix.enable = false.
  # This LaunchDaemon replicates that behaviour: runs as root on Sunday at 3:15am,
  # deletes all system/user profile generations older than 30 days, then GCs.
  launchd.daemons.nix-gc = {
    serviceConfig = {
      Label = "org.nixos.gc";
      ProgramArguments = [
        "${pkgs.nix}/bin/nix-collect-garbage"
        "--delete-older-than"
        "30d"
      ];
      StartCalendarInterval = [
        {
          Weekday = 0; # 0 = Sunday per launchd.plist(5); both 0 and 7 are Sunday, 0 is conventional
          Hour = 3;
          Minute = 15;
        }
      ];
      RunAtLoad = false;
      UserName = "root";
      GroupName = "wheel";
    };
  };

  # ============================================================================
  # Adopt the Determinate installer's stock /etc/nix/nix.custom.conf
  # ============================================================================
  # On a brand-new machine the Determinate Nix installer writes a stock
  # nix.custom.conf (two comment lines) that nix-darwin's /etc collision check
  # does not recognize, aborting the FIRST activation with "Unexpected files
  # in /etc" (hit on jevans-ms 2026-07-02). Listing the stock file's hash lets
  # activation adopt and overwrite it automatically — no manual rename step on
  # fresh installs. If a future installer version changes the stock content,
  # append its sha256 here (shasum -a 256 /etc/nix/nix.custom.conf).
  environment.etc."nix/nix.custom.conf".knownSha256Hashes = [
    "3bd68ef979a42070a44f8d82c205cfd8e8cca425d91253ec2c10a88179bb34aa"
  ];

  # ============================================================================
  # Home-manager compatibility workaround
  # ============================================================================
  # home-manager's darwin module accesses nix.package even when nix is disabled
  # See: https://github.com/nix-community/home-manager/issues/4026
  nix.package = lib.mkForce pkgs.nix;
}
