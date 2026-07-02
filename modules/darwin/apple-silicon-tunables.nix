# Apple Silicon System Tunables
#
# Boot-time and runtime knobs for Apple Silicon (M-series) hosts that run
# heavy local AI inference + capture workloads (vllm-mlx, etc.).
# All knobs target native macOS surfaces (sysctl, pmset, mdutil, tmutil,
# user defaults, launchctl) — there is no first-class nix-darwin option for
# any of them.
#
# Module boundary: this module owns inference-performance knobs. Sleep/wake
# *timer policy* (sleep, displaysleep, disksleep, womp, autorestart) lives in
# energy.nix; both modules legitimately drive pmset.
#
# Persistence: the iogpu/vm sysctls are VOLATILE (reset on reboot), so they
# live in scripts/apple-silicon-sysctls.sh and re-apply via a RunAtLoad
# launchd daemon AND at activation. The pmset/mdutil/tmutil/defaults/launchctl
# knobs persist or are verify-only and run at activation via
# scripts/apple-silicon-tunables.sh.

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
    enable = lib.mkEnableOption "Apple Silicon system tunables for AI workloads";

    # --- Category 1: unified memory / GPU ---------------------------------
    wiredLimitMb = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 118000;
      description = ''
        iogpu.wired_limit_mb — wired-memory ceiling for the IOGPU subsystem.
        0 = OS default (~75% of RAM). Default 118000 = ~92% of a 128 GB host.
        Volatile: re-applied at every boot via a one-shot launchd daemon.
      '';
    };

    wiredLwmMb = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        iogpu.wired_lwm_mb — low-water-mark companion to wiredLimitMb. No
        authoritative source recommends changing it for inference; exposed for
        completeness. null = leave the macOS default untouched (recommended).
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
        vm.compressor_mode — 1 = no compression/no swap, 2 = compression/no
        swap, 3 = no compression/swap, 4 = compression + swap (macOS default).
        Mode 2 risks a hard allocation failure instead of swapping when a model
        exceeds RAM; exposed but left at the macOS default. Generally needs a
        reboot to fully take effect. null = do not touch (recommended).
      '';
    };

    # --- Category 2: power / pmset (inference-perf knobs) -----------------
    pmset = {
      lowPowerMode = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = false;
        description = ''
          pmset -a lowpowermode. Low Power Mode throttles the SoC for battery
          life and badly stalls inference, so the default is false (off) on all
          power sources. null = leave the macOS default untouched.
        '';
      };
      powerNap = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = false;
        description = ''
          pmset -a powernap. Power Nap wakes the machine for background iCloud/
          mail work; false avoids spurious wakes during long inference (safe
          win). null = leave the macOS default untouched.
        '';
      };
      proximityWake = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = false;
        description = ''
          pmset -a proximitywake. Wake when a nearby Apple device wakes; false
          reduces spurious wakes (safe win). null = leave the macOS default.
        '';
      };
      disableSleep = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          pmset -a disablesleep. Hard-disables idle sleep entirely
          (sledgehammer). Left null because system.energy.sleep.ac = 0 already
          prevents AC idle sleep; prefer that. null = leave the macOS default.
        '';
      };
      tcpKeepAlive = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          pmset -a tcpkeepalive. Keeps TCP alive while the system is in standby
          — only relevant when serving models over the network during sleep.
          null = leave the macOS default untouched.
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
        Desired macOS Energy Mode (System Settings → Battery → Energy Mode).
        High Power Mode is the single biggest sustained-throughput lever on an
        M4 Max laptop (raises the fan ceiling, defers thermal throttling) but
        CANNOT be set programmatically — there is no sysctl/pmset/defaults key.
        Set it once in System Settings (or via an MDM Energy Saver profile).
        Activation reads `pmset -g custom`, parses the AC-block powermode, and
        logs a WARN on drift. "unmanaged" skips the check. Verify/nudge only —
        never enforced.
      '';
    };

    # --- Category 4: App Nap ----------------------------------------------
    appNapDisabledFor = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "dev.vllm-mlx.server" ];
      description = ''
        User-defaults bundle IDs to mark NSAppSleepDisabled=YES for, so macOS
        does not throttle long-lived inference daemons via App Nap.
      '';
    };

    # --- Category 7: background contention --------------------------------
    huggingfaceVolume = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/HuggingFace";
      description = "Path to the HuggingFace cache volume; Spotlight indexing is disabled here.";
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
        HuggingFace volume default is sourced from huggingfaceVolume so
        overriding that option keeps the exclusion in sync.
      '';
    };

    # --- Category 8: Metal debug env --------------------------------------
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
        Best-effort guard with verification; the canonical fix is for the
        inference LaunchAgent (nix-ai programs.mlx) to never export them. Empty
        list disables the guard.
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
    ];

    # Boot-time: re-apply the VOLATILE iogpu/vm sysctls on every restart. The
    # sysctls reset to default on reboot, so we rely on launchd RunAtLoad
    # rather than an /etc/sysctl.conf-style mechanism. Label/log path are kept
    # stable (was set-iogpu-wired-limit) to avoid orphaning the old plist; it
    # now runs the shared volatile-sysctl script (wired limit + optional lwm +
    # optional compressor mode).
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

    # darwin-rebuild switch: apply everything. Volatile sysctls first (so a
    # rebuild takes effect immediately, not just next boot), then the
    # persistent / verify-only knobs. All values escaped via lib.escapeShellArg.
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
