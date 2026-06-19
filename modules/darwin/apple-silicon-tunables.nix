# Apple Silicon System Tunables
#
# Boot-time and runtime knobs for Apple Silicon (M-series) hosts that run
# heavy local AI inference + capture workloads (vllm-mlx, etc.).
# All knobs target native macOS surfaces (sysctl, pmset, mdutil, tmutil,
# user defaults) — there is no first-class nix-darwin option for any of them.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.system.appleSiliconTunables;
  userConfig = import ../../lib/user-config.nix;

  applyScript = pkgs.writeShellApplication {
    name = "apple-silicon-tunables-apply";
    runtimeInputs = [ ];
    text = builtins.readFile ./scripts/apple-silicon-tunables.sh;
  };
in
{
  options.system.appleSiliconTunables = {
    enable = lib.mkEnableOption "Apple Silicon system tunables for AI workloads";

    wiredLimitMb = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 118000;
      description = ''
        iogpu.wired_limit_mb — wired-memory ceiling for the IOGPU subsystem.
        0 = OS default (~75% of RAM). Re-applied at every boot via a one-shot
        launchd daemon.
      '';
    };

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

    appNapDisabledFor = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "dev.vllm-mlx.server" ];
      description = ''
        User-defaults bundle IDs to mark NSAppSleepDisabled=YES for, so macOS
        does not throttle long-lived inference daemons via App Nap.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Boot-time: re-apply the wired-memory ceiling on every restart. The
    # sysctl is volatile, so we rely on launchd RunAtLoad rather than
    # baking it into a /etc/sysctl.conf-style mechanism.
    launchd.daemons.set-iogpu-wired-limit = {
      serviceConfig = {
        Label = "dev.local.set-iogpu-wired-limit";
        ProgramArguments = [
          "/usr/sbin/sysctl"
          "-w"
          "iogpu.wired_limit_mb=${toString cfg.wiredLimitMb}"
        ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/var/log/set-iogpu-wired-limit.log";
        StandardErrorPath = "/var/log/set-iogpu-wired-limit.log";
      };
    };

    # darwin-rebuild switch: invoke the apply script with the configured knobs.
    # All values escaped via lib.escapeShellArg — defense against unusual
    # path characters or future user-configurable option values.
    system.activationScripts.appleSiliconTunables.text = ''
      WIRED_LIMIT_MB=${lib.escapeShellArg (toString cfg.wiredLimitMb)} \
      HF_VOLUME=${lib.escapeShellArg cfg.huggingfaceVolume} \
      TM_EXCLUDES=${lib.escapeShellArg (lib.concatStringsSep ":" cfg.timeMachineExcludes)} \
      APPNAP_BUNDLES=${lib.escapeShellArg (lib.concatStringsSep ":" cfg.appNapDisabledFor)} \
      USER_NAME=${lib.escapeShellArg userConfig.user.name} \
        ${lib.getExe applyScript} || true
    '';
  };
}
