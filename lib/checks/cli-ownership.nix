# One owner per AI CLI, asserted on the platform that owns the risk.
#
# Claude Code is installed on darwin by its native installer (nix-claude-code
# `programs.claude.install = "native"`), so Nix must not also build it into
# home.packages: a second, shadowed `claude` would never run.
#
# nix-ai cannot assert this itself. Its regression suite is scoped to
# x86_64-linux, so it only ever evaluates the Linux side. This check runs where
# the real darwin host is evaluated.
#
# Pass the REAL evaluated host configurations. `lib/checks.nix` receives
# `darwinConfigurations = { }` from flake.nix, so a check placed there never
# materializes and passes vacuously.
{ pkgs, configs }:
let
  inherit (pkgs.lib)
    concatStringsSep
    mapAttrsToList
    filter
    flatten
    ;

  # pnames owned outside Nix. pname is the reliable discriminator: `name`
  # carries the version, and a substring match on "claude-code" also hits
  # claude-code-plugins and the nix-claude-code source tree.
  brewOwned = (import ../homebrew-policy.nix).nativeClis;

  offendersFor =
    hostName: cfg:
    let
      users = cfg.config.home-manager.users or { };
      offendersForUser =
        userName: userCfg:
        map (p: "${hostName}/${userName}: ${p.pname}") (
          filter (p: builtins.elem (p.pname or "") brewOwned) userCfg.home.packages
        );
    in
    flatten (mapAttrsToList offendersForUser users);

  # Generic over every host and every home-manager user on purpose: a new host
  # must not be able to reintroduce the dual-install by not being listed here.
  offenders = flatten (mapAttrsToList offendersFor configs);
in
assert
  offenders == [ ]
  || throw ''
    AI CLI dual-install regression: a native installer owns these binaries on
    darwin, so Nix must not install them. Found them in home.packages:

    ${concatStringsSep "\n" offenders}

    Fix `programs.claude.install` in nix-ai (modules/claude-config.nix) rather
    than removing this check.
  '';
pkgs.runCommand "check-cli-ownership" { } ''
  echo "no natively installed AI CLI is also installed by Nix on any darwin host"
  touch $out
''
