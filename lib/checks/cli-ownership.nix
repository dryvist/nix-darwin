# One owner per AI CLI, asserted on the platform that owns the risk.
#
# Claude Code remains Homebrew-owned on darwin. Codex moved to nix-home's
# nixpkgs package; hosts/common/home.nix sets that same package on
# `programs.codex` so nix-ai's launcher targets its installed binary.
#
# nix-ai cannot assert this itself. Its regression suite is scoped to
# x86_64-linux, so it only ever evaluates the Linux side of that conditional.
# Remove the `isDarwin` guard there and Linux keeps working, nix-ai's CI stays
# green, and the Mac silently regains a second `claude` with nothing to say so.
# This check is that signal, and it runs where the real host is evaluated.
#
# Pass the REAL evaluated host configurations. `lib/checks.nix` receives
# `darwinConfigurations = { }` from flake.nix, so a check placed there never
# materializes and passes vacuously — the same false negative this repo already
# documents for `nix flake check` on a Mac.
{ pkgs, configs }:
let
  inherit (pkgs.lib)
    concatStringsSep
    mapAttrsToList
    filter
    flatten
    ;

  # pname is the reliable discriminator. `name` carries the version, and a
  # substring match on "claude-code" also hits claude-code-plugins and the
  # nix-claude-code source tree, neither of which is the binary.
  brewOwned = [
    "claude-code"
  ];

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
    AI CLI dual-install regression: Homebrew owns these binaries on darwin, so
    nix-ai must leave `package = null`. Found them in home.packages:

    ${concatStringsSep "\n" offenders}

    Fix the Homebrew package declaration rather than removing this check.
  '';
pkgs.runCommand "check-cli-ownership" { } ''
  echo "no brew-owned AI CLI is installed by Nix on any darwin host"
  touch $out
''
