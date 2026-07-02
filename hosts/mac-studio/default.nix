# mac-studio Host Configuration
#
# Apple Silicon Mac Studio (M4 Max, 128 GB RAM). Headless, always-on LAN
# inference / batch server (`class = server`).
#
# Shared system config — module imports, networking.hostName, OrbStack, the
# vllm-mlx Cribl log-shipping pipeline, and server-class macOS defaults
# (Wake-on-LAN, network tuning, energyMode) — lives in ../common/default.nix.
# This file adds only the host-unique bits: ComputerName and this machine's
# headless inference/power tuning.

{ ... }:

{
  imports = [ ../common/default.nix ];

  # nix-darwin sets HostName + LocalHostName from networking.hostName, but NOT
  # ComputerName — set it explicitly so the Finder/AirDrop name matches.
  networking.computerName = "jevans-ms";

  # ==========================================================================
  # System-Level Tuning (headless inference server)
  # ==========================================================================
  system = {
    # --- Apple Silicon Tunables ---
    appleSiliconTunables = {
      enable = true;
      # Headless: no ~25 GB GUI desktop working set, so reclaim the wired-memory
      # ceiling the laptop deliberately leaves at the OS default (0). 118000 ≈
      # 92 % of 128 GB (the module default). Benchmark on-machine.
      wiredLimitMb = 118000;
      # energyMode comes from the server class default ("unmanaged") in ../common.
    };

    # --- Resource Limits (file descriptors / processes) ---
    # Raise kern.maxfiles* + launchctl maxfiles to 524288 for large mmap'd models.
    resourceLimits.enable = true;

    # --- Energy & Sleep ---
    # Always-on: never idle-sleep on AC (module sleep.ac default = 0). Wake-on-LAN,
    # network tuning, and energyMode come from the server class in ../common.
    energy.enable = true;
  };
}
