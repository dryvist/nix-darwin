# macbook-m4 Host Configuration
#
# Apple Silicon MacBook Pro (M4 Max, 128GB RAM). Primary development machine.
#
# Shared system config (module imports, networking.hostName, OrbStack,
# file-extensions, openssh, and the MLX model-server Cribl log-shipping pipeline shared
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
  programs = {
    # Persistently disable unwanted updaters and remove junk plists.
    # Edit these lists to add/remove services — enforced on every rebuild.
    streamline-login = {
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

    # --- OpenBao-minted AWS STS credential_process ---
    # Installs the `openbao-aws-creds` wrapper for the tf-proxmox AWS profile.
    # Secret-zero (VAULT_ADDR + the terraform AppRole) is supplied ambiently by
    # `doppler run`, not a local keychain. See modules/darwin/apps/openbao-aws-creds.nix.
    openbao-aws-creds.enable = true;

    # --- OpenBao-backed GitHub token provider ---
    # Runtime behavior and operator commands are canonical at
    # https://docs.dryvist.com/d/runbooks/github-token-openbao-migration/.
    # This host only installs the provider; it holds no GitHub credential.
    openbao-github-creds.enable = true;

  };

  # ==========================================================================
  # System-Level Tuning (inference performance, power, limits, network)
  # ==========================================================================
  system = {
    # --- Auto-login ---
    # Land in the user session on every restart so login-time agents (the
    # claude-continuity auto-resume, the MLX user agents) come up unattended.
    # With FileVault on, macOS defers this to the pre-boot unlock: the unlock
    # user proceeds straight to the desktop, so the effect is one password at
    # disk unlock and zero prompts after.
    defaults.loginwindow.autoLoginUser = userConfig.user.name;

    # --- Apple Silicon Tunables ---
    # Wired-memory ceiling, pmset perf flags, App Nap, Spotlight + TM excludes,
    # Metal debug-env guard. See modules/darwin/apple-silicon-tunables.nix.
    appleSiliconTunables = {
      enable = true;
      # High Power Mode is the biggest sustained-throughput lever on the laptop.
      # Activation sets it (AC powermode 2) and re-reads to confirm it stuck.
      # Never set this below "high" here: this host must never run throttled.
      energyMode = "high";
      # pmset perf flags (lowPowerMode / powerNap / proximityWake off) and the
      # Metal debug-env guard use the module's safe-win defaults.
      #
      # Standalone-mode LLM budget — the single knob; everything downstream
      # derives (see modules/darwin/apple-silicon-tunables.nix):
      #   maxLocalLlmGb 100 GiB  ->  wiredLimitMb 102400 MiB (100 * 1024)
      #                          ->  osReserveGb 28 GiB unwired desktop headroom
      # L1 wired ceiling is exact: 102400 * 1024^2 = 100 GiB (107.37 GB decimal).
      # Memory safety is now layered in absolute bytes, furthest-from-OS first:
      # per-model serving budget < L2 in-process cap (mlx-lm mx.set_memory_limit
      # = 99 GiB, just under this ceiling) < L1 wired ceiling < RAM, with the
      # 28 GiB reserve keeping WindowServer + desktop out of swap. The old
      # util-fraction trip pairing (gpuMemoryUtilization) was vllm-mlx-only and
      # could never sit below the ceiling; it is retired under mlx-lm.
      # Interactive box, LLM-first.
      # https://docs.jacobpevans.com/local-llm/memory-ceilings
      maxLocalLlmGb = 100;
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
