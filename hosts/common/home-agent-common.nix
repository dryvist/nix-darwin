# What every automation identity's home shares (lib/user-config.nix
# `agentUsers`), whatever its trust tier. Imported by flake.nix for each one,
# alongside its own home-agent.nix or home-open-llm.nix.
{
  config,
  lib,
  osConfig,
  pkgs,
  userConfig,
  ...
}:
let
  home = config.home.homeDirectory;
  signingKey = "${home}/.ssh/git_signing_ed25519";

  agentSigningKey = pkgs.writeShellApplication {
    name = "agent-signing-key";
    runtimeInputs = [ pkgs.openssh ];
    text = builtins.readFile ./scripts/agent-signing-key.sh;
  };
in
{
  # The workspace root is this identity's own folder on the shared agent
  # volume (nix-home workspace.gitHome); agent-launch starts sessions there.
  workspace.gitHome = "${userConfig.agentGitRoot}/${config.home.username}";

  # Homebrew owns the Claude Code and Codex binaries on darwin
  # (lib/checks/cli-ownership.nix), and the system PATH omits its prefix.
  # Appended, so a Nix-provided binary of the same name still wins.
  home.sessionVariablesExtra = ''
    export PATH="$PATH:${osConfig.homebrew.prefix}/bin"
  '';

  # nix-home signs with the operator's GPG key, which this account does not
  # hold. Sign with this identity's own SSH key instead.
  programs.git.signing = {
    format = lib.mkForce "ssh";
    key = lib.mkForce "${signingKey}.pub";
    signByDefault = true;
  };

  home.activation.agentSigningKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe agentSigningKey} ${lib.escapeShellArg signingKey}
  '';
}
