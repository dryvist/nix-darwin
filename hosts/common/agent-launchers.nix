# Operator-side launchers: each agent CLI runs as its automation identity.
#
# Every tool in lib/user-config.nix `agentUsers.<identity>.tools` becomes a zsh
# function that hands off to `agent-launch`, so typing `claude` starts Claude
# Code as the `claude` account in that account's $GIT_HOME/claude (one Touch
# ID). See scripts/agent-launch.sh for what the session gets.
#
# Functions, not PATH commands: only the operator's interactive shell is
# redirected. Scripts, and `command <tool>`, still reach the operator's own
# binary deliberately.
{
  lib,
  pkgs,
  userConfig,
  ...
}:
let
  agentLaunch = pkgs.writeShellApplication {
    name = "agent-launch";
    text = builtins.readFile ./scripts/agent-launch.sh;
  };

  launcher =
    identity: tool:
    "${tool}() { ${lib.getExe agentLaunch} ${
      lib.escapeShellArgs [
        identity
        tool
      ]
    } \"$@\"; }";
in
{
  programs.zsh.initContent = lib.mkAfter (
    lib.concatStringsSep "\n" (
      lib.concatMap (agent: map (launcher agent.name) agent.tools) (lib.attrValues userConfig.agentUsers)
    )
  );
}
