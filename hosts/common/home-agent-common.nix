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

  inherit (config.agentGit) author;
in
{
  options.agentGit.author = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "git user.name for this identity's commits.";
          };
          email = lib.mkOption {
            type = lib.types.str;
            description = "git user.email for this identity's commits.";
          };
        };
      }
    );
    default = null;
    description = ''
      The author this identity's commits carry. null keeps the operator's
      name and email, which nix-home sets for every home.
    '';
  };

  config = {
    # The workspace root is this identity's own folder on the shared agent
    # volume (nix-home workspace.gitHome); agent-launch starts sessions there.
    workspace.gitHome = "${userConfig.agentGitRoot}/${config.home.username}";

    # Homebrew owns the Claude Code and Codex binaries on darwin
    # (lib/checks/cli-ownership.nix), and the system PATH omits its prefix.
    # Appended, so a Nix-provided binary of the same name still wins.
    home.sessionVariablesExtra = ''
      export PATH="$PATH:${osConfig.homebrew.prefix}/bin"
    '';

    programs.git = {
      # nix-home signs with the operator's GPG key, which this account does not
      # hold. Sign with this identity's own SSH key instead.
      signing = {
        format = lib.mkForce "ssh";
        key = lib.mkForce "${signingKey}.pub";
        signByDefault = true;
      };

      settings.user = lib.mkIf (author != null) {
        name = lib.mkForce author.name;
        email = lib.mkForce author.email;
      };
    };

    home.activation.agentSigningKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe agentSigningKey} ${lib.escapeShellArg signingKey}
    '';
  };
}
