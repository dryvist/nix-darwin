import re

with open('hosts/macbook-m4/default.nix', 'r') as f:
    content = f.read()

replacement = """  # ==========================================================================
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
}"""

# regex to replace from <<<<<<< HEAD to >>>>>>> origin/main
content = re.sub(r'<<<<<<< HEAD.*?=======\n.*?\n>>>>>>> origin/main\n    };\n  };\n}', replacement, content, flags=re.DOTALL)

with open('hosts/macbook-m4/default.nix', 'w') as f:
    f.write(content)

