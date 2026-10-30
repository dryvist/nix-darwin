# One owner per AI CLI, asserted on the platform that owns the risk.
#
# Claude Code and Codex are installed by Homebrew on darwin — declared in
# nix-ai's lib/homebrew.nix and upgraded by the weekly `brew upgrade` agent.
# The nix-ai modules therefore set `package = null` on darwin, so Nix does not
# build a second, shadowed copy. That dual-install is exactly what this
# arrangement replaced: a cask won PATH while Nix built a binary that never ran.
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
    attrNames
    concatStringsSep
    mapAttrsToList
    filter
    flatten
    ;

  # pname -> the Homebrew cask that owns it. pname is the reliable
  # discriminator. `name` carries the version, and a substring match on
  # "claude-code" also hits claude-code-plugins and the nix-claude-code source
  # tree, neither of which is the binary.
  brewCasks = (import ../homebrew-policy.nix).cliCasks;
  brewOwned = attrNames brewCasks;

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

  # The other half of one owner: with Nix skipping the binary, the cask must be
  # declared, or the launcher execs a path nothing installs.
  missingCasksFor =
    hostName: cfg:
    let
      declared = map (c: c.name or c) (cfg.config.homebrew.casks or [ ]);
    in
    map (c: "${hostName}: ${c}") (
      filter (c: !(builtins.elem c declared)) (builtins.attrValues brewCasks)
    );
  missingCasks = flatten (mapAttrsToList missingCasksFor configs);
in
assert
  offenders == [ ]
  || throw ''
    AI CLI dual-install regression: Homebrew owns these binaries on darwin, so
    nix-ai must leave `package = null`. Found them in home.packages:

    ${concatStringsSep "\n" offenders}

    Fix the `pkgs.stdenv.hostPlatform.isDarwin` conditional in nix-ai
    (modules/claude-config.nix, modules/codex/default.nix) rather than
    removing this check.
  '';
assert
  missingCasks == [ ]
  || throw ''
    AI CLI owner missing: these hosts do not declare the Homebrew cask that owns
    the binary, so nothing installs it:

    ${concatStringsSep "\n" missingCasks}

    Enable it in lib/host-profiles.nix (`homebrew.ai`) rather than removing
    this check.
  '';
pkgs.runCommand "check-cli-ownership" { } ''
  echo "every brew-owned AI CLI is cask-declared and not installed by Nix on any darwin host"
  touch $out
''
