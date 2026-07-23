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
  pkgs,
  ...
}:

let
  cfg = config.system.appleSiliconTunables;
  userConfig = import ../../lib/user-config.nix;

  # null → "" (leave the macOS default untouched); otherwise stringify.
  optStr = v: if v == null then "" else toString v;
  # tri-state pmset flag: null → "" (skip), false → "0", true → "1".
  pmsetBool = v: if v == null then "" else (if v then "1" else "0");

  # Volatile sysctls (iogpu/vm) — shared by the boot daemon and activation.
  sysctlsScript = pkgs.writeShellApplication {
    name = "apple-silicon-sysctls-apply";
    runtimeInputs = [ ];
    text = builtins.readFile ./scripts/apple-silicon-sysctls.sh;
  };

  # Environment for the volatile-sysctl script (reused by daemon + activation).
  sysctlsEnv = {
    WIRED_LIMIT_MB = toString cfg.wiredLimitMb;
    WIRED_LWM_MB = optStr cfg.wiredLwmMb;
    VM_COMPRESSOR_MODE = optStr cfg.vmCompressorMode;
  };

  # Persistent / verify-only knobs — activation only.
  applyScript = pkgs.writeShellApplication {
    name = "apple-silicon-tunables-apply";
    runtimeInputs = [ ];
    text = builtins.readFile ./scripts/apple-silicon-tunables.sh;
  };
in
{
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
        is the biggest sustained-throughput lever on an M4 Max laptop but CANNOT
        be set programmatically — set it once in System Settings or via MDM.
        Activation reads `pmset -g custom`, parses the AC-block powermode, and
        WARNs on drift. "unmanaged" skips the check. Verify/nudge only.
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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.wiredLimitMb < 2147483647;
        message = "system.appleSiliconTunables.wiredLimitMb must stay below INT_MAX (2147483647).";
      }
      {
        assertion = cfg.wiredLwmMb == null || cfg.wiredLwmMb < cfg.wiredLimitMb;
        message = "system.appleSiliconTunables.wiredLwmMb (low-water mark) must be below wiredLimitMb.";
      }
      {
        # LLM budget cannot exceed installed RAM.
        assertion = cfg.maxLocalLlmGb == null || cfg.maxLocalLlmGb <= cfg.physicalRamGb;
        message = "system.appleSiliconTunables.maxLocalLlmGb (${toString cfg.maxLocalLlmGb} GiB) cannot exceed physicalRamGb (${toString cfg.physicalRamGb} GiB).";
      }
      {
        # Derived reserve must leave macOS enough unwired RAM.
        assertion = cfg.osReserveGb == null || cfg.osReserveGb >= 8;
        message = "system.appleSiliconTunables: osReserveGb (physicalRamGb minus maxLocalLlmGb) must leave macOS at least 8 GiB unwired; got ${toString cfg.osReserveGb} GiB. Lower maxLocalLlmGb.";
      }
    ];

    # Boot-time: re-apply the VOLATILE iogpu/vm sysctls on every restart via
    # launchd RunAtLoad. Label/log path kept stable to avoid orphaning the old
    # plist. The shared script retries the wired-limit write until the IOGPU
    # sysctl node registers, so an early-boot race no longer strands the ceiling.
    launchd.daemons.set-iogpu-wired-limit = {
      serviceConfig = {
        Label = "dev.local.set-iogpu-wired-limit";
        ProgramArguments = [ (lib.getExe sysctlsScript) ];
        EnvironmentVariables = sysctlsEnv;
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/var/log/set-iogpu-wired-limit.log";
        StandardErrorPath = "/var/log/set-iogpu-wired-limit.log";
      };
    };

    # darwin-rebuild switch: volatile sysctls first (so a rebuild takes effect
    # immediately, not just next boot), then persistent/verify-only knobs.
    # All values escaped via lib.escapeShellArg.
    system.activationScripts.appleSiliconTunables.text = ''
      WIRED_LIMIT_MB=${lib.escapeShellArg sysctlsEnv.WIRED_LIMIT_MB} \
      WIRED_LWM_MB=${lib.escapeShellArg sysctlsEnv.WIRED_LWM_MB} \
      VM_COMPRESSOR_MODE=${lib.escapeShellArg sysctlsEnv.VM_COMPRESSOR_MODE} \
        ${lib.getExe sysctlsScript} || true

      HF_VOLUME=${lib.escapeShellArg cfg.huggingfaceVolume} \
      TM_EXCLUDES=${lib.escapeShellArg (lib.concatStringsSep ":" cfg.timeMachineExcludes)} \
      APPNAP_BUNDLES=${lib.escapeShellArg (lib.concatStringsSep ":" cfg.appNapDisabledFor)} \
      USER_NAME=${lib.escapeShellArg userConfig.user.name} \
      PMSET_LOWPOWERMODE=${lib.escapeShellArg (pmsetBool cfg.pmset.lowPowerMode)} \
      PMSET_POWERNAP=${lib.escapeShellArg (pmsetBool cfg.pmset.powerNap)} \
      PMSET_PROXIMITYWAKE=${lib.escapeShellArg (pmsetBool cfg.pmset.proximityWake)} \
      PMSET_DISABLESLEEP=${lib.escapeShellArg (pmsetBool cfg.pmset.disableSleep)} \
      PMSET_TCPKEEPALIVE=${lib.escapeShellArg (pmsetBool cfg.pmset.tcpKeepAlive)} \
      ENERGY_MODE_DESIRED=${lib.escapeShellArg cfg.energyMode} \
      METAL_UNSET_VARS=${lib.escapeShellArg (lib.concatStringsSep ":" cfg.metalDebugEnvToUnset)} \
        ${lib.getExe applyScript} || true
    '';
  };
}
