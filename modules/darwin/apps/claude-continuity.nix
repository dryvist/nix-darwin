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
in
{
  options.programs.claude-continuity = {
    enable = lib.mkEnableOption "login-time auto-resume of an armed Claude Code mission (reboot continuity)";

    user = lib.mkOption {
      type = lib.types.str;
      description = "macOS login user whose armed Claude session is resumed at login.";
    };
  };

  config = lib.mkIf cfg.enable {
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
  };
}
