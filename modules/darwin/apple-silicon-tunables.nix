# Apple Silicon System Tunables
#
# Native macOS knobs (sysctl, pmset, mdutil, tmutil, defaults, launchctl) for
# M-series hosts running heavy local AI inference; no first-class nix-darwin
# option exists. This module owns inference-perf knobs; sleep/wake timer policy
# lives in energy.nix (both drive pmset).
#
# The iogpu/vm sysctls are VOLATILE (reset on reboot): scripts/apple-silicon-
# sysctls.sh, re-applied via a RunAtLoad launchd daemon and at activation.
# Persistent/verify-only knobs run at activation via apple-silicon-tunables.sh.

{
  lib,
  config,
  ...
}:

let
  cfg = config.system.appleSiliconTunables;
  userConfig = import ../../lib/user-config.nix;
in
{
  # The volatile-sysctl boot daemon + activation script live in the config half,
  # split out for the 12 KB file-size gate.
  imports = [ ./apple-silicon-tunables-apply.nix ];

  options.system.appleSiliconTunables = {
    enable = lib.mkEnableOption "Apple Silicon system tunables for AI";

    # Category 1: unified memory / GPU
    physicalRamGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 128;
      description = ''
        Installed physical RAM in GiB — a hardware constant. Denominator of the
        osReserveGb derivation and the maxLocalLlmGb assert.
      '';
    };

    maxLocalLlmGb = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 96;
      description = ''
        The single hand-set memory knob: GiB of wired memory for the local LLM
        subsystem. When set, DERIVES wiredLimitMb (this times 1024) and
        osReserveGb (physicalRamGb minus this) — set THIS, not wiredLimitMb, so
        ceiling and reserve stay one decision. null leaves wiredLimitMb on its
        own default. Serving-affecting; deploy in a maintenance window.
      '';
    };

    osReserveGb = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      readOnly = true;
      default = if cfg.maxLocalLlmGb == null then null else cfg.physicalRamGb - cfg.maxLocalLlmGb;
      defaultText = lib.literalExpression "physicalRamGb minus maxLocalLlmGb (null when maxLocalLlmGb is unset)";
      description = ''
        Computed GiB left unwired as OS headroom (physicalRamGb minus
        maxLocalLlmGb). Read-only; the assert below floors it so the LLM budget
        can never starve macOS.
      '';
    };

    wiredLimitMb = lib.mkOption {
      type = lib.types.ints.unsigned;
      # Derived: maxLocalLlmGb * 1024; bare 118000 for a host not on that input.
      default = if cfg.maxLocalLlmGb == null then 118000 else cfg.maxLocalLlmGb * 1024;
      defaultText = lib.literalExpression "maxLocalLlmGb times 1024 when set, 118000 when unset";
      description = ''
        iogpu.wired_limit_mb — wired-memory ceiling in MiB. Volatile: re-applied
        every boot via a one-shot launchd daemon. Prefer maxLocalLlmGb (this
        derives from it); a host not on that input sets it directly.
        max_recommended_working_set_size = wiredLimitMb * 1024^2. 0 = OS default
        (~84% of RAM). This is the L1 wired ceiling; the mlx-lm serving stack
        sets an in-process L2 cap (programs.mlx.memoryHardLimitGb) just below it.
        The old gpuMemoryUtilization pairing was vllm-mlx-only and is retired.
        https://docs.jacobpevans.com/local-llm/memory-ceilings
      '';
    };

    wiredLwmMb = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        iogpu.wired_lwm_mb — low-water-mark companion to wiredLimitMb. Exposed
        for completeness; no source recommends changing it for inference.
        null = macOS default (recommended).
      '';
    };

    vmCompressorMode = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          1
          2
          3
          4
        ]
      );
      default = null;
      description = ''
        vm.compressor_mode — 1 = no compress/no swap, 2 = compress/no swap,
        3 = no compress/swap, 4 = compress + swap (macOS default). Mode 2 risks a
        hard allocation failure instead of swapping; left at the default. Needs a
        reboot. null = do not touch.
      '';
    };

    # Category 2: power / pmset (inference-perf knobs)
    pmset = {
      lowPowerMode = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = false;
        description = ''
          pmset -a lowpowermode. Throttles the SoC and stalls inference, so
          default false (off) on all power sources. null = macOS default.
        '';
      };
      powerNap = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = false;
        description = ''
          pmset -a powernap. Wakes the machine for background iCloud/mail work;
          false avoids spurious wakes during long inference. null = macOS default.
        '';
      };
      proximityWake = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = false;
        description = ''
          pmset -a proximitywake. Wake when a nearby Apple device wakes; false
          reduces spurious wakes. null = macOS default.
        '';
      };
      disableSleep = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          pmset -a disablesleep. Hard-disables idle sleep entirely. Left null
          because system.energy.sleep.ac = 0 already prevents AC idle sleep.
        '';
      };
      tcpKeepAlive = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          pmset -a tcpkeepalive. Keeps TCP alive in standby — only relevant when
          serving models over the network during sleep. null = macOS default.
        '';
      };
    };

    energyMode = lib.mkOption {
      type = lib.types.enum [
        "high"
        "automatic"
        "low"
        "unmanaged"
      ];
      default = "high";
      description = ''
        Desired macOS Energy Mode (System Settings → Battery). High Power Mode
        is the biggest sustained-throughput lever on an M4 Max laptop, and IS
        settable as root: activation writes `pmset -c/-b powermode` and re-reads
        it per power source to confirm it stuck. "unmanaged" skips it entirely.

        powermode values are 0 = Automatic, 1 = Low Power, 2 = High Power.
        Because "high" is AC-only on portables, it requests 2 on AC and 0
        (Automatic) on battery — macOS offers no High Power on battery.

        This option owns the preference slot that `pmset.lowPowerMode` also
        writes (they are one slot under two names), so whenever this is not
        "unmanaged" the boolean stands down rather than racing it.
      '';
    };

    # Category 4: App Nap
    appNapDisabledFor = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "dev.mlx-model-server" ];
      description = ''
        User-defaults bundle IDs to mark NSAppSleepDisabled=YES, so macOS does
        not throttle long-lived inference daemons via App Nap.
      '';
    };

    # Category 7: background contention
    huggingfaceVolume = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/HuggingFace";
      description = "HuggingFace cache volume path; Spotlight indexing disabled here.";
    };

    timeMachineExcludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${userConfig.user.homeDir}/.cache/uv"
        cfg.huggingfaceVolume
      ];
      defaultText = lib.literalExpression ''
        [
          "''${userConfig.user.homeDir}/.cache/uv"
          config.system.appleSiliconTunables.huggingfaceVolume
        ]
      '';
      description = ''
        Absolute paths to add to the Time Machine exclusion list. The
        HuggingFace volume default sources from huggingfaceVolume so overriding
        that option keeps the exclusion in sync.
      '';
    };

    # Category 8: Metal debug env
    metalDebugEnvToUnset = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "MTL_DEBUG_LAYER"
        "MTL_SHADER_VALIDATION"
        "MTL_SHADER_VALIDATION_DEFAULT_STATE"
        "MTL_CAPTURE_ENABLED"
        "MTL_HUD_ENABLED"
      ];
      description = ''
        Metal debug/validation env vars to clear from the launchd user context
        via `launchctl unsetenv`. Any one set silently taxes every inference.
        Canonical fix is the inference LaunchAgent (nix-ai programs.mlx) never
        exporting them. Empty list disables the guard.
      '';
    };
  };

}
