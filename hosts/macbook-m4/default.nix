# macbook-m4 Host Configuration
#
# Apple Silicon MacBook Pro (M4 Max, 128GB RAM). Primary development machine.
#
# Shared system config (module imports, networking.hostName, OrbStack,
# file-extensions, openssh, and the vllm-mlx Cribl log-shipping pipeline shared
# by all inference hosts) lives in ../common/default.nix. This file adds only the
# host-unique bits: curated login-item streamlining and this machine's
# inference/power tuning values.

{
  config,
  ...
}:

let
  # User identity (homeDir) for the host-unique config below. Host identity
  # (hostName, registry params) is consumed in ../common.
  userConfig = import ../../lib/user-config.nix;
in
{
  imports = [ ../common/default.nix ];

  # --- Streamline Login Items ---
  # Persistently disable unwanted updaters and remove junk plists.
  # Edit these lists to add/remove services — enforced on every rebuild.
  programs.streamline-login = {
    enable = true;

    # Junk/dead plists to delete from ~/Library/LaunchAgents/
    removePlists = [
      "com.google.keystone.agent.plist" # Legacy Google Keystone (empty, replaced by GoogleUpdater)
      "com.google.keystone.xpcservice.plist" # Legacy Google Keystone (empty)
    ];

    # User-domain services to disable (updaters, redundant apps, broken daemons)
    disableUserServices = [
      "com.google.GoogleUpdater.wake" # Google hourly updater
      "us.zoom.updater" # Zoom hourly updater
      "us.zoom.updater.login.check" # Zoom login check at login
      # Boot-time race condition daemons — crash-loop before dependencies ready,
      # corrupt WindowServer client dispatch table, cause sustained UI lag/freezes
      "com.apple.universalaccessd" # No accessibility features enabled
      "com.apple.macos.studentd" # Classroom daemon, no MDM enrollment
      "com.apple.passd" # Apple Wallet not used
    ];

    # System-domain services to disable
    disableSystemServices = [
      "com.google.GoogleUpdater.wake.system" # Google system updater (hourly)
      "com.duosecurity.duoappupdater" # Duo updater (every 10 minutes)
      "us.zoom.ZoomDaemon" # Zoom privileged helper daemon
    ];

    # Dangling zsh completion symlinks to prune on every rebuild. nix-homebrew
    # leaves a dead `_brew` here (its /opt/homebrew/completions target is never
    # materialized), which makes compinit warn on every new login shell.
    pruneCompletionDirs = [
      "/opt/homebrew/share/zsh/site-functions"
    ];
  };

  # --- OpenBao keychain-backed secret-zero ---
  # Dedicated 72h-auto-lock keychain + resolver agent for OpenBao AppRole
  # credentials. See modules/darwin/apps/openbao-keychain.nix.
  programs.openbao-keychain.enable = true;

  # ==========================================================================
  # System-Level Tuning (inference performance, power, limits, network)
  # ==========================================================================
  system = {
    # --- Apple Silicon Tunables ---
    # Wired-memory ceiling, pmset perf flags, App Nap, Spotlight + TM excludes,
    # Metal debug-env guard. See modules/darwin/apple-silicon-tunables.nix.
    appleSiliconTunables = {
      enable = true;
      # High Power Mode is the biggest sustained-throughput lever on the laptop
      # but cannot be set via CLI; this drives a verify/nudge at activation.
      # Set it once: System Settings -> Battery -> Energy Mode -> High Power.
      energyMode = "high";
      # pmset perf flags (lowPowerMode / powerNap / proximityWake off) and the
      # Metal debug-env guard use the module's safe-win defaults.
      # 104000 (not the module's 118000 default): guarantee 24 GB of unwirable
      # headroom. At 118000 only ~10 GB was guaranteed pageable and the desktop
      # working set alone exceeds 25 GB, so any large resident MLX model pushed
      # the host into compressor + swap saturation (nix-mac-performance RC14;
      # 2026-06-10 snapshot: swap 94 % with a single healthy 53 GB worker).
      # Still fits the largest model in use (~75 GB resident).
      wiredLimitMb = 0; # OS default (~96 GB on 128 GB); leave headroom for the rest of the system
      # Set explicitly rather than relying on the module default: a list option
      # drops its default once any config value is set, so the generic excludes
      # must be a config def here for a private host layer to append to via merge.
      timeMachineExcludes = [
        "${userConfig.user.homeDir}/.cache/uv"
        config.system.appleSiliconTunables.huggingfaceVolume
      ];
    };

    # --- Resource Limits (file descriptors / processes) ---
    # Raise kern.maxfiles* + launchctl maxfiles to 524288 for large mmap'd models.
    resourceLimits.enable = true;

    # --- Network Tuning (socket buffers) ---
    # Exposed but OFF — enable + set buffers only if LAN model-serving becomes a
    # measured bottleneck. Loopback inference does not need it.
    networkTuning.enable = false;

    # --- Thunderbolt RDMA link (cluster mode, worker / rank 1) ---
    # Disabled: conflicts with the deployed nightLinkPrep converge daemon
    # (hosts/common), which owns the TB link (bridge0 sweep + static IPv4) and
    # is the mechanism the cluster rendezvous was proven on. Re-enable only
    # when the zero-IP rework in modules/darwin/night-link.nix replaces
    # nightLinkPrep in the same change.
    rdmaLink.enable = false;

    # --- Energy & Sleep Configuration ---
    energy = {
      enable = true;
      displaysleep = 30; # Display sleeps after 30 minutes
      sleep = {
        ac = 0; # Never sleep when plugged in (AC power)
        battery = 60; # Sleep after 1 hour on battery
      };
      # Set disksleep to non-zero when battery sleep is non-zero (Apple best practice)
      # This ensures optimal power state transition on battery (Safe Sleep requires this)
      disksleep = 10; # Disk optimizes power after 10 minutes (before system sleep at 60)
      wakeOnMagicPacket = true;
      autoRestartOnPowerLoss = true;
    };
  };
}
