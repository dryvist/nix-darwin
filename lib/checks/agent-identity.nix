# Every automation identity, on every host, is ready to run its sessions:
#
# - it signs commits with its own SSH key, kept in its own home, never the
#   operator's GPG key that nix-home sets for every home;
# - its workspace root is its own folder under agentGitRoot;
# - its session PATH reaches the Homebrew prefix, where Claude Code and Codex
#   live on darwin (cli-ownership.nix);
# - the operator's shell has a launcher for each tool it runs;
# - the host declares the volume that agentGitRoot names;
# - agentGit.author, when set, replaces the operator's commit author.
#
# Pass the REAL evaluated host configurations (see cli-ownership.nix for why a
# check fed an empty set passes vacuously).
{
  pkgs,
  configs,
  userConfig,
}:
let
  inherit (pkgs) lib;

  problemsFor =
    hostName: cfg:
    let
      c = cfg.config;
      users = c.home-manager.users;
      operatorInit = users.${userConfig.user.name}.programs.zsh.initContent;
      volumes = map (v: "/Volumes/${v.name}") c.programs.apfsVolumes.volumes;
      agentProblems =
        name: agent:
        let
          hm = users.${name};
          inherit (hm.programs.git) signing;
          fail = msg: "${hostName}/${name}: ${msg}";
        in
        lib.optional (signing.format != "ssh") (fail "git signing format is not ssh")
        ++ lib.optional (!lib.hasPrefix "${agent.homeDir}/" signing.key) (
          fail "signing key is outside its home"
        )
        ++ lib.optional (!signing.signByDefault) (fail "commits are not signed by default")
        ++ lib.optional (hm.workspace.gitHome != "${userConfig.agentGitRoot}/${name}") (
          fail "workspace root is not its agentGitRoot folder"
        )
        ++ lib.optional (!lib.hasInfix "${c.homebrew.prefix}/bin" hm.home.sessionVariablesExtra) (
          fail "session PATH misses the Homebrew prefix"
        )
        ++ map (tool: fail "operator shell has no `${tool}` launcher") (
          lib.filter (tool: !lib.hasInfix "${tool}() {" operatorInit) agent.tools
        );
    in
    lib.optional (
      !builtins.elem userConfig.agentGitRoot volumes
    ) "${hostName}: no APFS volume for ${userConfig.agentGitRoot}"
    ++ lib.concatLists (lib.mapAttrsToList agentProblems userConfig.agentUsers);

  # agentGit.author replaces the operator's name and email that nix-home sets.
  # Set it on every identity of one host and read back the rendered git config.
  author = {
    name = "agent-check";
    email = "agent-check@example.invalid";
  };
  withAuthor = (lib.head (lib.attrValues configs)).extendModules {
    modules = [
      {
        home-manager.users = lib.mapAttrs (_: _: { agentGit.author = author; }) userConfig.agentUsers;
      }
    ];
  };
  authorProblems = lib.concatMap (
    name:
    lib.optional (
      withAuthor.config.home-manager.users.${name}.programs.git.iniContent.user.email != author.email
    ) "${name}: agentGit.author does not reach git user.email"
  ) (lib.attrNames userConfig.agentUsers);

  problems = lib.concatLists (lib.mapAttrsToList problemsFor configs) ++ authorProblems;
in
assert
  problems == [ ]
  || throw ''
    Automation identity not ready:

    ${lib.concatStringsSep "\n" problems}
  '';
pkgs.runCommand "check-agent-identity" { } ''
  echo "every automation identity signs with its own key, starts in its own workspace, and reaches its tools"
  touch $out
''
