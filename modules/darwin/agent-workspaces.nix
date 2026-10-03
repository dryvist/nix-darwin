# Workspace folders for the automation identities: <agentGitRoot>/<identity>
# and one folder per tool under it (lib/user-config.nix `agentUsers.*.tools`).
# Each identity's nix-home `workspace.gitHome` points at its folder
# (hosts/common/home-agent-common.nix), and agent-launch starts every session
# in $GIT_HOME/<tool>. The volume itself is declared per host in `apfsVolumes`.
{
  lib,
  pkgs,
  ...
}:
let
  userConfig = import ../../lib/user-config.nix;

  agentWorkspaces = pkgs.writeShellApplication {
    name = "agent-workspaces";
    text = builtins.readFile ./scripts/agent-workspaces.sh;
  };
in
{
  system.activationScripts.postActivation.text = lib.mkAfter (
    lib.concatMapStringsSep "\n" (
      agent:
      "${lib.getExe agentWorkspaces} ${
        lib.escapeShellArgs (
          [
            userConfig.agentGitRoot
            agent.name
          ]
          ++ agent.tools
        )
      }"
    ) (lib.attrValues userConfig.agentUsers)
  );
}
