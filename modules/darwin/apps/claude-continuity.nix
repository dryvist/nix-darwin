# Reboot-Continuity Auto-Resume for Claude Code
#
# A RunAtLoad launchd user agent that, on login, resumes an "armed" Claude
# Code session inside a dedicated detached tmux session. Purpose: a planned
# reboot (e.g. clearing leaked RDMA Protection Domains during cluster work)
# must not lose an in-flight autonomous mission — the mission auto-continues
# the moment the user logs back in.
#
# Human dependency: with FileVault on and auto-login off, NOTHING runs until
# the user unlocks and logs in. This agent makes the continuation instant
# after that unavoidable step; it cannot remove the step.
#
# Arming is runtime state, never nix (see the script header for the file
# format under ~/.claude/run/continuity/). No armed file = permanent no-op.
# The script consumes the armed file after one successful launch and only
# fires when the machine has rebooted since arming, so darwin-rebuild's
# apply-time RunAtLoad fire is safe while the original session still runs.
#
# Auth uses the claude CLI's own login session (macOS Keychain), no token on
# disk. The login keychain is unlocked
# by the login itself, so a RunAtLoad agent can authenticate.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude-continuity;
  homeDir = "/Users/${cfg.user}";
  logDir = "${homeDir}/Library/Logs/claude-continuity";

  # Resolve the vendor claude install first, then the per-user nix profile
  # (tmux), system profile, and base system.
  agentPath = lib.concatStringsSep ":" [
    "${homeDir}/.local/bin"
    "/etc/profiles/per-user/${cfg.user}/bin"
    "/run/current-system/sw/bin"
    "/opt/homebrew/bin"
    "/usr/bin"
    "/bin"
  ];

  # No runtimeInputs: tmux must come from the user's own profile via PATH so
  # the client matches the version of any tmux server already running for
  # this user (a nixpkgs-pinned client can refuse an older server).
  resumeScript = pkgs.writeShellApplication {
    name = "claude-continuity-resume";
    text = builtins.readFile ./scripts/claude-continuity-resume.sh;
  };
  sessions = config.programs.agentSessions;
  sessionEnvironment = {
    HOME = sessions.homeDirectory;
    USER = sessions.user;
    LOGNAME = sessions.user;
    SHELL = "/bin/sh";
    TERM = "xterm-256color";
    PATH = "/etc/profiles/per-user/${sessions.user}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
  }
  // sessions.environment;
  sessionAgent = name: session: {
    serviceConfig = {
      Label = "com.nix-darwin.agent-session-${name}";
      ProgramArguments = [
        "${pkgs.coreutils}/bin/env"
        "-i"
      ]
      ++ lib.mapAttrsToList (key: value: "${key}=${value}") sessionEnvironment
      ++ [
        (toString (
          pkgs.writeShellScript "agent-session-${name}" ''
            set -eu
            if ! ${pkgs.tmux}/bin/tmux -N "$@" has-session -t ${lib.escapeShellArg name} 2>/dev/null; then
              ${pkgs.tmux}/bin/tmux "$@" -f /dev/null new-session -d -s ${lib.escapeShellArg name} -c ${lib.escapeShellArg session.workingDirectory} ${pkgs.coreutils}/bin/env -- ${lib.escapeShellArgs session.command}
            fi
            trap '${pkgs.tmux}/bin/tmux -N "$@" kill-server 2>/dev/null || true' EXIT
            trap 'exit 0' TERM INT
            ${pkgs.tmux}/bin/tmux -N "$@" set-option -g @agent-launcher-pid "$$"
            ${pkgs.tmux}/bin/tmux -N "$@" wait-for session-ended &
            waiter=$!
            wait "$waiter"
          ''
        ))
        "-L"
        "agent-session-${name}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      ProcessType = "Background";
      Nice = 10;
      LowPriorityIO = true;
      SoftResourceLimits.NumberOfFiles = sessions.openFileLimit;
      HardResourceLimits.NumberOfFiles = sessions.openFileLimit;
      StandardOutPath = "${sessions.homeDirectory}/Library/Logs/agent-sessions/${name}.log";
      StandardErrorPath = "${sessions.homeDirectory}/Library/Logs/agent-sessions/${name}.error.log";
    };
  };
in
{
  options.programs.agentSessions = {
    enable = lib.mkEnableOption "persistent CLI sessions in dedicated tmux servers";
    user = lib.mkOption {
      type = lib.types.str;
      description = "macOS login user running the sessions.";
    };
    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/Users/${sessions.user}";
      description = "Home directory for the session processes and logs.";
    };
    openFileLimit = lib.mkOption {
      type = lib.types.ints.positive;
      description = "Shared agent CLI open-file limit.";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Explicit environment additions for the session processes.";
    };
    sessions = lib.mkOption {
      default = { };
      description = "Named CLI sessions; attach using tmux -L agent-session-NAME attach -t NAME.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.nonEmptyListOf lib.types.str;
              description = "Executable and arguments, including the CLI's native remote option.";
            };
            workingDirectory = lib.mkOption {
              type = lib.types.str;
              description = "Existing working directory for the session.";
            };
          };
        }
      );
    };
  };

  options.programs.claude-continuity = {
    enable = lib.mkEnableOption "login-time auto-resume of an armed Claude Code mission (reboot continuity)";

    user = lib.mkOption {
      type = lib.types.str;
      description = "macOS login user whose armed Claude session is resumed at login.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      launchd.user.agents.claude-continuity.serviceConfig = {
        Label = "com.nix-darwin.claude-continuity";
        ProgramArguments = [ "${resumeScript}/bin/claude-continuity-resume" ];
        RunAtLoad = true;
        ProcessType = "Background";
        StandardOutPath = "${logDir}/resume.log";
        StandardErrorPath = "${logDir}/resume.error.log";
        EnvironmentVariables = {
          HOME = homeDir;
          PATH = agentPath;
        };
      };

      # Log dir with user ownership so the user agent can write its logs.
      system.activationScripts.postActivation.text = ''
        /usr/bin/install -d -o ${cfg.user} -g staff "${logDir}"
      '';
    })
    (lib.mkIf sessions.enable {
      assertions = lib.mapAttrsToList (name: _: {
        assertion = builtins.match "[a-zA-Z0-9_-]+" name != null;
        message = "programs.agentSessions session names must contain only letters, digits, underscores, and hyphens.";
      }) sessions.sessions;
      launchd.user.agents = lib.mapAttrs' (
        name: session: lib.nameValuePair "agent-session-${name}" (sessionAgent name session)
      ) sessions.sessions;
      system.activationScripts.preActivation.text = ''
        /usr/bin/install -d -o ${lib.escapeShellArg sessions.user} -g staff ${lib.escapeShellArg "${sessions.homeDirectory}/Library/Logs/agent-sessions"}
      '';
    })
  ];
}
