# macbook-m4 Host Configuration
#
# Apple Silicon MacBook Pro (M4 Max, 128GB RAM)
# Primary development machine using nix-darwin
#
# This file imports darwin modules and configures host-specific settings.

{ config, pkgs, ... }:

let
  # User-specific configuration (hostname, identity, etc.)
  userConfig = import ../../lib/user-config.nix;
in
{
  imports = [
    # Darwin system modules
    ../../modules/darwin/common.nix
  ];

  # ==========================================================================
  # Host-Specific Settings
  # ==========================================================================
  # Settings that are unique to this specific machine
  # Hostname from lib/user-config.nix

  networking.hostName = userConfig.host.name;

  # ==========================================================================
  # System Services
  # ==========================================================================

  # SSH/Remote Login
  # Enables macOS Remote Login via launchd (System Settings > General > Sharing)
  # Allows SSH access to this development machine
  services.openssh.enable = true;

  # ==========================================================================
  # Programs
  # ==========================================================================

  programs = {
    # --- OrbStack ---
    # Container runtime as system-level application
    # - System-wide installation via nix-darwin
    # - Dedicated APFS volume for data storage
    # - Data symlink configured in home.nix using mkOutOfStoreSymlink
    #
    # NOTE: package.enable = true installs OrbStack system-wide
    # TCC permissions (Docker/Linux VM access) may need re-granting after rebuilds
    # For TCC stability, set package.enable = false and add to home.packages instead
    orbstack = {
      enable = true;
      # package.enable = false: OrbStack is installed via Homebrew cask (greedy = true)
      # in modules/darwin/homebrew.nix. Homebrew installs to /Applications/ as a real
      # copy, so TCC permissions (Docker socket, Linux VM) persist across darwin-rebuild.
      # Previously, nixpkgs installed a symlink to a /nix/store path that changes on
      # every rebuild, forcing TCC re-granting each time.
      package.enable = false;
      # orb start exits 0 in <1s; KeepAlive=true was throttle-respawning it into
      # a runningboardd assertion flood. OrbStack.app manages its own startup.
      background.enable = false;
      dataVolume = {
        enable = true;
        name = "ContainerData";
        apfsContainer = "disk3"; # Find with: diskutil apfs list
      };
    };

    # --- File Extension Mappings ---
    # Custom file extensions recognized as tar.gz archives
    # Enables Finder auto-extract and shell autocomplete
    file-extensions = {
      enable = true;
    };

    # --- Cribl Edge ---
    # Log collection agent, standalone + GitOps-managed (this file owns the
    # node's config; Cribl Cloud fleets are reserved for Linux machines).
    # Inline sources/pipelines below cover the local LLM stack; events ship
    # over Cribl TCP to the HAProxy-fronted Stream workers (port value from
    # terraform-proxmox constants service_ports.cribl_s2s) which forward to
    # the Splunk `llm` index. See docs/CRIBL-GITOPS.md.
    # NOTE: the local-Stream cutover (→127.0.0.1:10301) is reverted while the
    # containerized Stream's CPU/DNS issue is fixed — see cribl-stream below.
    cribl-edge = {
      enable = true;
      mode = "standalone";
      standalone.configFiles = {
        "inputs.yml" = ''
          inputs:
            in_llm_logs:
              type: file
              disabled: false
              mode: manual
              filenames:
                - ${userConfig.user.homeDir}/Library/Logs/vllm-mlx/vllm-mlx.log
                - ${userConfig.user.homeDir}/Library/Logs/vllm-mlx/vllm-mlx.error.log
              sendToRoutes: false
              connections:
                - pipeline: llm_logs
                  output: cribl_stream
            in_system_metrics:
              type: system_metrics
              disabled: false
              sendToRoutes: false
              connections:
                - pipeline: llm_metrics
                  output: cribl_stream
        '';
        "outputs.yml" = ''
          outputs:
            cribl_stream:
              type: cribl_tcp
              # Homelab HAProxy (FQDN), load-balanced across the Cribl Stream workers.
              host: haproxy.pve.jacobpevans.com
              port: 10300
              pqEnabled: true
        '';
        # Model-server logs: the manager (Go) and its workers (Python) share
        # the same two files; sourcetype is derived per line.
        "pipelines/llm_logs/conf.yml" = ''
          output: default
          functions:
            - id: eval
              filter: "true"
              conf:
                add:
                  - name: index
                    value: "'llm'"
                  - name: sourcetype
                    value: "_raw.match(/^(INFO|DEBUG|WARNING|ERROR|CRITICAL):/) ? 'vllm:mlx' : 'llamaswap'"
        '';
        "pipelines/llm_metrics/conf.yml" = ''
          output: default
          functions:
            - id: eval
              filter: "true"
              conf:
                add:
                  - name: index
                    value: "'llm'"
                  - name: sourcetype
                    value: "'mlx:metrics'"
        '';
      };
      packs = {
        cc-edge-the-mac-pack-io = pkgs.fetchzip {
          url = "https://github.com/JacobPEvans/cc-edge-the-mac-pack-io/releases/download/v0.3.0/cc-edge-the-mac-pack-io-v0.3.0.crbl";
          extension = "tar.gz";
          hash = "sha256-rPPAkedltxT8RWgP2xXil1o6x13HQK+SRgihuheJAks=";
          stripRoot = false;
        };
      };
    };

    # --- Cribl Stream (local egress aggregator, Apple container) ---
    # Single-instance Cribl Stream in an Apple `container`: local sources ship to
    # 127.0.0.1:10301 and it forwards to the Proxmox Stream tier (haproxy:10300).
    # Resource-capped (cpus/memory/single worker) and given the LAN DNS resolver +
    # search domain; the output queue is bounded. See docs/CRIBL-GITOPS.md.
    cribl-stream = {
      enable = true;
      user = userConfig.user.name;
      inputPort = 10301;
      apiPort = 9000;
      cpus = 1;
      memory = "1g";
      maxWorkers = 1;
      dnsServers = userConfig.host.lanDnsServers;
      dnsSearch = [ userConfig.host.lanSearchDomain ];
      configFiles = {
        "inputs.yml" = ''
          inputs:
            in_edge_s2s:
              type: cribl_tcp
              disabled: false
              host: 0.0.0.0
              port: 10301
              sendToRoutes: false
              connections:
                - pipeline: passthrough
                  output: proxmox_stream
        '';
        "outputs.yml" = ''
          outputs:
            proxmox_stream:
              type: cribl_tcp
              # Homelab HAProxy (FQDN), load-balanced across the Proxmox Cribl Stream workers.
              host: haproxy.pve.jacobpevans.com
              port: 10300
              pqEnabled: true
              # Bounded on-disk queue: cap size and drop when full.
              pqMaxFileSize: 256 MB
              pqMaxSize: 1 GB
              pqOnBackpressure: drop
        '';
        # Passthrough for now; index/sourcetype enrichment moves here from Edge
        # once Edge is repointed (Edge captures, Stream enriches + egresses).
        "pipelines/passthrough/conf.yml" = ''
          output: default
          functions: []
        '';
      };
    };

    # --- Streamline Login Items ---
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
        "com.ollama.ollama" # Redundant — vllm-mlx is primary inference server
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
    };
  };

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
