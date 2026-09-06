# Endpoint credential-residue scan.
#
# A daily user agent that reports credential material left loose in the
# directories where it collects by accident. It reports; it never deletes.
#
# WHY A USER AGENT AND NOT A DAEMON: the directories it watches belong to the
# user, and running as root would let a scanner read material the user's own
# session cannot. A control aimed at accidental exposure should not widen the
# access it needs to look.
#
# The self-check inside the script matters more than the schedule. A scan that
# reports "clean" is indistinguishable from a scan whose patterns quietly
# stopped matching, so it proves it can still see a known-bad fixture before it
# is willing to report clean at all, and exits non-zero if it cannot.
#
# Log: ~/Library/Logs/credential-residue-scan.log, plus syslog markers under
# the tag `credential-residue-scan` for alert rules.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.credentialResidueScan;

  scanScript = pkgs.writeShellApplication {
    name = "credential-residue-scan";
    # DELIBERATELY EMPTY. This agent is macOS-only and the script is written
    # against the BSD utilities the system ships. Putting GNU coreutils on the
    # PATH silently changes what the flags MEAN rather than failing: BSD
    # `stat -f '%Lp'` prints a file's permission bits, while GNU `stat -f`
    # means --file-system and reads '%Lp' as a filename, so the variable ends
    # up holding a multi-line filesystem report instead of a mode.
    #
    # That was not caught by running the script directly -- a bare `bash` run
    # uses /usr/bin/stat and passes. It appeared only when the BUILT artifact
    # ran, which is the argument for testing the thing that ships rather than
    # the file it was built from.
    runtimeInputs = [ ];
    text = builtins.readFile ./scripts/credential-residue-scan.sh;
  };

  logFile = "${config.users.users.${cfg.user}.home}/Library/Logs/credential-residue-scan.log";
in
{
  options.local.credentialResidueScan = {
    enable = lib.mkEnableOption "daily endpoint credential-residue scan";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose directories are scanned, and who the agent runs as.";
    };

    directories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "$HOME/Downloads"
        "$HOME/Desktop"
      ];
      description = ''
        Directories to scan. Kept to the places credential material lands by
        accident rather than where it lives on purpose: a scan that walks a
        whole home directory reports the secret store's own files every run,
        and a control that always fires is one nobody reads.
      '';
    };

    startHour = lib.mkOption {
      type = lib.types.int;
      default = 11;
      description = ''
        Hour to run. Deliberately not a round number and not overnight -- this
        machine is a laptop and an agent scheduled while it is closed simply
        does not run, which presents as a control that never finds anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.credential-residue-scan = {
      serviceConfig = {
        Label = "dev.local.credential-residue-scan";
        ProgramArguments = [ "${scanScript}/bin/credential-residue-scan" ];
        StartCalendarInterval = [
          {
            Hour = cfg.startHour;
            Minute = 17;
          }
        ];
        # Not RunAtLoad: a rebuild is the moment the operator is busiest, and a
        # finding surfaced then competes with whatever the rebuild was for.
        RunAtLoad = false;
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
        EnvironmentVariables = {
          CREDENTIAL_RESIDUE_DIRS = lib.concatStringsSep " " cfg.directories;
        };
      };
    };
  };
}
