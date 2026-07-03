# Nix-Managed Scheduled Claude Code Jobs
#
# Declares unattended `claude -p` (headless print-mode) runs as launchd user
# agents on a server-class host. Each job is one `launchd.user.agents` entry
# fired by StartCalendarInterval.
#
# Design choices:
#
# - launchd, not the claude.ai "Scheduled Tasks" UI: schedules must be
#   declarative and reproducible from this repo, not clicked into a web UI that
#   no darwin-rebuild can reconstruct. The cloud routines repo is the home for
#   cloud-executed schedules; these run locally on the Studio's own clones.
#
# - Auth is the claude CLI's OWN login session — no token file, no sops, no
#   env injection. The Claude Code OAuth token must never live on disk (a file
#   readable by the launchd agent is readable by every AI process running as
#   that user); its only stores are Doppler / GitHub Actions secrets. Instead,
#   run `claude /login` once interactively on the host: the CLI keeps its
#   session in its own macOS Keychain entry (encrypted at rest, never a plain
#   file) and refreshes it itself. Known caveat: a nix rebuild can churn the
#   binary path behind the Keychain ACL, breaking headless auth until the next
#   interactive login — jobs fail safe with an auth error in their log.
#
# - No shell wrapper: launchd passes argv directly to the claude binary, so
#   nothing needs shell-escaping and no secret ever transits an env var,
#   the plist, or `ps` output.
#
# Logs land under ~/Library/Logs/claude-jobs/<name>.{log,error.log} and are
# rotated by the system newsyslog run via /etc/newsyslog.d/claude-jobs.conf.

{
  lib,
  config,
  ...
}:

let
  cfg = config.programs.claude-scheduled-jobs;
  homeDir = "/Users/${cfg.user}";
  logDir = "${homeDir}/Library/Logs/claude-jobs";

  # Per-user nix profile first (where `claude`, `git`, `gh` live), then the
  # system profile and Homebrew, then the base system — mirrors the maestro /
  # github-runner agent PATH shape so an unattended agent resolves the same
  # tools an interactive login shell would.
  agentPath = lib.concatStringsSep ":" [
    "/etc/profiles/per-user/${cfg.user}/bin"
    "/run/current-system/sw/bin"
    "/opt/homebrew/bin"
    "/usr/bin"
    "/bin"
  ];

  jobSchedule =
    schedule:
    {
      Hour = schedule.hour;
      Minute = schedule.minute;
    }
    // lib.optionalAttrs (schedule.weekday != null) {
      Weekday = schedule.weekday;
    };

  # Direct argv — no shell, no escaping, no credential material anywhere in
  # the command. claude authenticates from its own login-session credentials.
  jobProgram =
    job:
    [
      cfg.claudeBin
      "-p"
      job.prompt
    ]
    ++ job.extraArgs;

  mkAgent = name: job: {
    name = "claude-job-${name}";
    value.serviceConfig = {
      Label = "com.nix-darwin.claude-job-${name}";
      ProgramArguments = jobProgram job;
      StartCalendarInterval = [ (jobSchedule job.schedule) ];
      ProcessType = "Background";
      WorkingDirectory = job.workingDirectory;
      StandardOutPath = "${logDir}/${name}.log";
      StandardErrorPath = "${logDir}/${name}.error.log";
      EnvironmentVariables = {
        HOME = homeDir;
        PATH = agentPath;
      };
    };
  };

  scheduleType = lib.types.submodule {
    options = {
      hour = lib.mkOption {
        type = lib.types.ints.between 0 23;
        description = "Local hour (0-23) to run the job.";
      };
      minute = lib.mkOption {
        type = lib.types.ints.between 0 59;
        description = "Local minute (0-59) to run the job.";
      };
      weekday = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 0 7);
        default = null;
        description = "Optional launchd weekday (0/7 = Sunday); null runs daily.";
      };
    };
  };

  jobType = lib.types.submodule {
    options = {
      prompt = lib.mkOption {
        type = lib.types.str;
        description = "The prompt handed to `claude -p` for this job.";
      };
      workingDirectory = lib.mkOption {
        type = lib.types.str;
        default = homeDir;
        description = "Directory the job runs in (defaults to the user's home).";
      };
      schedule = lib.mkOption {
        type = scheduleType;
        description = "When the job fires (StartCalendarInterval).";
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments appended after `-p <prompt>` (each a separate argv entry).";
      };
    };
  };
in
{
  options.programs.claude-scheduled-jobs = {
    enable = lib.mkEnableOption "Nix-managed scheduled `claude -p` jobs (launchd user agents)";

    user = lib.mkOption {
      type = lib.types.str;
      description = "macOS login user that owns the agents and log directory.";
    };

    claudeBin = lib.mkOption {
      type = lib.types.str;
      default = "/etc/profiles/per-user/${cfg.user}/bin/claude";
      description = "Path to the claude CLI binary (defaults to the per-user nix profile).";
    };

    jobs = lib.mkOption {
      type = lib.types.attrsOf jobType;
      default = { };
      description = "Named scheduled Claude jobs; each becomes a launchd user agent.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents = lib.mapAttrs' mkAgent cfg.jobs;

    # Create the log dir with user ownership (install -d would otherwise leave
    # missing parents root-owned, blocking the user agent's log writes).
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${cfg.user} -g staff "${logDir}"
    '';

    # Rotate the job logs via the system newsyslog run (it reads
    # /etc/newsyslog.d/*.conf on macOS). One entry per job log file, owned by the
    # login user so root-run rotation re-creates them with the right ownership.
    environment.etc."newsyslog.d/claude-jobs.conf".text =
      let
        rotateLine = path: "${path} ${cfg.user}:staff 644 3 1024 * J";
        lines = lib.concatMap (name: [
          (rotateLine "${logDir}/${name}.log")
          (rotateLine "${logDir}/${name}.error.log")
        ]) (lib.attrNames cfg.jobs);
      in
      lib.concatStringsSep "\n" ([ "# logfilename [owner:group] mode count size when flags" ] ++ lines)
      + "\n";
  };
}
