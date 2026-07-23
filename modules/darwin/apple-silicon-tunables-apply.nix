# Config half of the Apple Silicon tunables module — split from
# apple-silicon-tunables.nix for the 12 KB file-size gate. Holds the volatile
# iogpu/vm sysctl boot daemon and the activation script; the option
# declarations stay in the sibling file. Composed via imports, so cfg resolves
# the same option set.
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
  config = lib.mkIf cfg.enable {
    # Put the volatile-sysctl script on the system PATH so the boot daemon can
    # reference it by a STABLE /run/current-system path (below) instead of a
    # bare /nix/store path. A bare store path is orphaned once nix-collect-garbage
    # removes the old generation, and launchd then fails the job at spawn with
    # EX_CONFIG (exit 78) before the script ever runs (log untouched) — observed
    # on the MacBook. /run/current-system/sw/bin/... always resolves to the live
    # generation and is never GC'd.
    environment.systemPackages = [ sysctlsScript ];

    # Boot-time: re-apply the VOLATILE iogpu/vm sysctls on every restart via
    # launchd RunAtLoad. Label/log path kept stable to avoid orphaning the old
    # plist. The shared script retries the wired-limit write until the IOGPU
    # sysctl node registers, so an early-boot race no longer strands the ceiling.
    launchd.daemons.set-iogpu-wired-limit = {
      serviceConfig = {
        Label = "dev.local.set-iogpu-wired-limit";
        ProgramArguments = [ "/run/current-system/sw/bin/${lib.getName sysctlsScript}" ];
        # launchd rejects empty-string EnvironmentVariables values and fails the
        # job at spawn with EX_CONFIG (78) — drop the empty keys (the script
        # treats unset the same as empty via ${VAR:-}).
        EnvironmentVariables = lib.filterAttrs (_: v: v != "") sysctlsEnv;
        RunAtLoad = true;
        # Retry on non-zero exit AND on spawn failure (EX_CONFIG), so a transient
        # exec failure self-recovers instead of stranding the wired ceiling at
        # the OS default until the next manual converge. The script exits 0 once
        # the sysctl write lands, so success does not relaunch.
        KeepAlive = {
          SuccessfulExit = false;
        };
        StandardOutPath = "/var/log/set-iogpu-wired-limit.log";
        StandardErrorPath = "/var/log/set-iogpu-wired-limit.log";
      };
    };

    # darwin-rebuild switch: volatile sysctls first (so a rebuild takes effect
    # immediately, not just next boot), then persistent/verify-only knobs.
    # Must hang off postActivation (mkAfter) — nix-darwin only runs its known
    # activation-script names, so a bare custom name (appleSiliconTunables) was
    # silently never executed and the ceiling only applied at boot via the
    # daemon. All values escaped via lib.escapeShellArg.
    system.activationScripts.postActivation.text = lib.mkAfter ''
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
