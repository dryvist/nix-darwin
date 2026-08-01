# System Resource Limits
#
# Raises file-descriptor and process limits for workloads that memory-map many
# multi-GB model shards and spawn large thread pools. The kern.* sysctls are
# VOLATILE (reset on reboot), so they re-apply via a RunAtLoad launchd daemon
# AND at activation; `launchctl limit maxfiles` is set in the same pass.
#
# There is no first-class nix-darwin option for these — native sysctl/launchctl
# surfaces only. Every value is exposed so it is documented even when left at a
# default; a null value means "leave the macOS default untouched".

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.system.resourceLimits;
  optStr = v: if v == null then "" else toString v;

  applyScript = pkgs.writeShellApplication {
    name = "system-limits-apply";
    runtimeInputs = [ ];
    text = builtins.readFile ./scripts/system-limits.sh;
  };

  # Reused by the root daemon, activation, and GUI-domain user LaunchAgent.
  limitsEnv = {
    MAXFILES = optStr cfg.maxFiles;
    MAXFILESPERPROC = optStr cfg.maxFilesPerProc;
    MAXPROC = optStr cfg.maxProc;
    MAXPROCPERUID = optStr cfg.maxProcPerUid;
    LAUNCHCTL_MAXFILES_SOFT = optStr cfg.launchctlMaxFiles.soft;
    LAUNCHCTL_MAXFILES_HARD = optStr cfg.launchctlMaxFiles.hard;
  };

  # INT_MAX guard — a kern.* limit at/above 2147483647 is read as a negative
  # 32-bit int and panics macOS.
  intMax = 2147483647;
  belowIntMax = v: v == null || v < intMax;
in
{
  options.system.resourceLimits = {
    enable = lib.mkEnableOption "Raised file-descriptor / process limits for large-model workloads";

    maxFiles = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 524288;
      description = ''
        kern.maxfiles — system-wide maximum open files. 524288 is a safe high
        value for large mmap'd model shards. Must stay below INT_MAX. null =
        leave the macOS default untouched.
      '';
    };

    maxFilesPerProc = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 524288;
      description = ''
        kern.maxfilesperproc — per-process maximum open files. null = leave the
        macOS default untouched.
      '';
    };

    maxProc = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        kern.maxproc — system-wide maximum processes. Exposed for completeness;
        the macOS default is adequate for a single serving process. null =
        leave the macOS default untouched.
      '';
    };

    maxProcPerUid = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        kern.maxprocperuid — per-user maximum processes. Exposed for
        completeness. null = leave the macOS default untouched.
      '';
    };

    launchctlMaxFiles = {
      soft = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 524288;
        description = ''
          Soft limit for `launchctl limit maxfiles`. Set both soft and hard, or
          set both null to skip the launchctl limit.
        '';
      };
      hard = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 524288;
        description = ''
          Hard limit for `launchctl limit maxfiles`. Set both soft and hard, or
          set both null to skip the launchctl limit.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = belowIntMax cfg.maxFiles;
        message = "system.resourceLimits.maxFiles must stay below INT_MAX (2147483647) or macOS panics.";
      }
      {
        assertion = belowIntMax cfg.maxFilesPerProc;
        message = "system.resourceLimits.maxFilesPerProc must stay below INT_MAX (2147483647).";
      }
      {
        assertion = belowIntMax cfg.maxProc;
        message = "system.resourceLimits.maxProc must stay below INT_MAX (2147483647).";
      }
      {
        assertion = (cfg.launchctlMaxFiles.soft == null) == (cfg.launchctlMaxFiles.hard == null);
        message = "system.resourceLimits.launchctlMaxFiles soft and hard must both be set or both null.";
      }
    ];

    # Boot-time: re-apply the volatile kern.* sysctls + launchctl limit.
    launchd.daemons.set-resource-limits = {
      serviceConfig = {
        Label = "dev.local.set-resource-limits";
        ProgramArguments = [ (lib.getExe applyScript) ];
        EnvironmentVariables = limitsEnv;
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/var/log/set-resource-limits.log";
        StandardErrorPath = "/var/log/set-resource-limits.log";
      };
    };

    # `launchctl limit` is scoped to the calling bootstrap domain. The root
    # daemon above cannot raise the GUI domain inherited by Terminal, Codex,
    # and other interactive tools, so apply the same maxfiles limit from a
    # user LaunchAgent at login.
    launchd.user.agents.set-resource-limits = {
      serviceConfig = {
        Label = "dev.local.set-resource-limits-user";
        ProgramArguments = [ (lib.getExe applyScript) ];
        EnvironmentVariables = limitsEnv // {
          SYSTEM_LIMITS_APPLY_SYSCTLS = "0";
        };
        RunAtLoad = true;
        KeepAlive = false;
      };
    };

    # darwin-rebuild switch: apply immediately (do not wait for next boot).
    system.activationScripts.resourceLimits.text = ''
      MAXFILES=${lib.escapeShellArg limitsEnv.MAXFILES} \
      MAXFILESPERPROC=${lib.escapeShellArg limitsEnv.MAXFILESPERPROC} \
      MAXPROC=${lib.escapeShellArg limitsEnv.MAXPROC} \
      MAXPROCPERUID=${lib.escapeShellArg limitsEnv.MAXPROCPERUID} \
      LAUNCHCTL_MAXFILES_SOFT=${lib.escapeShellArg limitsEnv.LAUNCHCTL_MAXFILES_SOFT} \
      LAUNCHCTL_MAXFILES_HARD=${lib.escapeShellArg limitsEnv.LAUNCHCTL_MAXFILES_HARD} \
        ${lib.getExe applyScript}
    '';
  };
}
