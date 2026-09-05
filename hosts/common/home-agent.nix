# Home-manager configuration for the automation identity
#
# Deliberately not hosts/common/home.nix. That file is the operator's
# daily-driver environment: MLX serving and cluster signing, OrbStack volume
# wiring, copyApps GUI placement, Cribl agents. All of those want a GUI launchd
# domain the automation account does not have, and none of them are needed to
# run a coding agent.
#
# What this account gets is the `server` preset plus whatever nix-ai and
# nix-home put in every home (flake.nix `sharedModules`), which is where Claude
# Code and Codex come from. Both of those module sets derive every path from
# `config.home.homeDirectory`, so they land in this account's own home with no
# parameterisation.

{
  lib,
  userConfig,
  ...
}:

{
  # Headless role: drops the GUI editor, GUI pinentry, document-skills runtime
  # and the other desktop features. Unlike the operator's home this is not
  # driven by the host class — the account is headless on every host.
  home-profile.preset = "server";

  programs = {
    # Reading the operator's checkouts trips git's ownership check, because
    # they belong to another uid. Marking the workspace root safe keeps `git
    # status` in a read-only inspection from failing; it grants no write
    # access, which the filesystem permissions still deny.
    git.settings.safe.directory = [ "${userConfig.user.homeDir}/git" ];

    # nix-ai enables cecli unconditionally, and its
    # tree-sitter-language-pack pin does not build on nixpkgs 26.05 — the same
    # override the operator's home carries (hosts/common/home.nix).
    cecli.enable = lib.mkForce false;

    # This account drives coding agents; it does not serve models. nix-ai
    # enables the local inference server by default, and its logical-role
    # assertion then has no catalog to resolve against, because the catalog is
    # populated per host in the operator's home.
    mlx.enable = lib.mkForce false;
  };
}
