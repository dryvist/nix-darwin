# One owner per Claude Code binary, asserted on the real evaluated hosts.
#
# nix-claude-code's programs.claude.install picks the owner. When it is "brew",
# programs.claude.brewCask names the cask: the host must declare it, and Nix
# must not also install the claude-code package.
#
# Pass the REAL evaluated host configurations; lib/checks.nix receives
# `darwinConfigurations = { }` and would pass vacuously.
{ pkgs, configs }:
let
  inherit (pkgs.lib)
    concatStringsSep
    mapAttrsToList
    filter
    flatten
    ;

  problemsFor =
    hostName: cfg:
    let
      declared = map (c: c.name or c) (cfg.config.homebrew.casks or [ ]);
      forUser =
        userName: userCfg:
        let
          cask = userCfg.programs.claude.brewCask or null;
          nixClaude = filter (p: (p.pname or "") == "claude-code") userCfg.home.packages;
        in
        if cask == null then
          [ ]
        else
          (
            if builtins.elem cask declared then
              [ ]
            else
              [ "${hostName}/${userName}: cask ${cask} not declared" ]
          )
          ++ map (_: "${hostName}/${userName}: claude-code also installed by Nix") nixClaude;
    in
    flatten (mapAttrsToList forUser (cfg.config.home-manager.users or { }));

  problems = flatten (mapAttrsToList problemsFor configs);
in
assert problems == [ ] || throw "Claude Code ownership:\n${concatStringsSep "\n" problems}";
pkgs.runCommand "check-cli-ownership" { } ''
  echo "every brew-installed Claude Code cask is declared and not also built by Nix"
  touch $out
''
