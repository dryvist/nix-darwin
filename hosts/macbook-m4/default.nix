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
    # Ships the `openbao-github-creds` wrapper (git credential helper + gh env
    # source) that is now the ONLY GitHub token path — the local GH_PAT_*
    # keychain tiers have been retired (see terraform-proxmox
    # docs/github-token-openbao-migration runbook). Tokens are ephemeral GitHub
    # App installation tokens, with a break-glass App-JWT mint fallback (#1776).
    # Secret-zero (VAULT_ADDR + the GitHub AppRole) is supplied ambiently by
    # `doppler run`.
    openbao-github-creds.enable = true;

    # --- Reboot-continuity auto-resume ---
    # Login-time LaunchAgent that resumes an armed Claude Code mission in tmux,
    # so a planned reboot (e.g. clearing leaked RDMA Protection Domains during
    # cluster work) doesn't lose the in-flight session. No-op unless armed at
    # runtime. See modules/darwin/apps/claude-continuity.nix.
    claude-continuity = {
      enable = true;
      user = userConfig.user.name;
    };
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
      # High Power Mode is the biggest sustained-throughput lever on the laptop
      # but cannot be set via CLI; this drives a verify/nudge at activation.
      # Set it once: System Settings -> Battery -> Energy Mode -> High Power.
      energyMode = "high";
      # pmset perf flags (lowPowerMode / powerNap / proximityWake off) and the
      # Metal debug-env guard use the module's safe-win defaults.
      #
      # Standalone-mode wired ceiling: 84000 MiB = 88.08 GB, leaving 46.0 GiB
      # unwirable as desktop headroom. Paired with gpuMemoryUtilization = 0.55
      # in lib/hosts/macbook-m4.nix — change both together, never one alone.
      # https://docs.jacobpevans.com/local-llm/memory-ceilings
      wiredLimitMb = 84000;
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
