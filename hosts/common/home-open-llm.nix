# Home-manager configuration for the `open-llm` automation identity
#
# The second dedicated agent account (see modules/darwin/agent-identity.nix):
# runs opencode and the cursor CLI, and nothing else. Same headless `server`
# preset as home-agent.nix, the same launchd-domain and model-serving
# exclusions, plus every other coding agent nix-ai turns on by default forced
# off — this identity is scoped to two tools, and a lower-trust tool should
# not find a configured claude or codex sitting next to it.
#
# What "off" means here: the `mkForce false` lines remove home-manager
# CONFIGURATION for this account. `claude` and `codex` also exist system-wide
# as Homebrew casks (/opt/homebrew/bin), which nothing in this repo can scope
# per user — so `command -v codex` still resolves as this account; what it
# does not get is a config, a login, or a place in this home's PATH. Some
# shared AI packages also arrive via ungated `home.packages` (nix-ai
# ai-tools.nix) and are likewise not removable from here.

{
  lib,
  userConfig,
  ...
}:

{
  home-profile.preset = "server";

  programs = {
    # Reading the operator's checkouts trips git's ownership check, because
    # they belong to another uid. Marking the workspace root safe keeps `git
    # status` in a read-only inspection from failing; it grants no write
    # access, which the filesystem permissions still deny.
    git.settings.safe.directory = [ "${userConfig.user.homeDir}/git" ];

    # Same exclusions as home-agent.nix, same reasons: cecli's dep pin does
    # not build on nixpkgs 26.05; mlx's logical-role assertion has no catalog
    # outside the operator's home; herdr's launchd agent targets a gui/<uid>
    # domain this account does not have.
    cecli.enable = lib.mkForce false;
    mlx.enable = lib.mkForce false;
    herdr.enable = lib.mkForce false;

    # Every other coding agent nix-ai enables unconditionally
    # (modules/default.nix). cursor and opencode are deliberately left at
    # their default — they are this identity's whole purpose.
    claude.latest.enable = lib.mkForce false;
    codex.enable = lib.mkForce false;
    qwen-code.enable = lib.mkForce false;
    antigravity-ide.enable = lib.mkForce false;
    antigravity-cli.enable = lib.mkForce false;
    fabric.enable = lib.mkForce false;
  };

  # Same gui/<uid> domain problem as herdr. Nothing signs commits from this
  # account, so there is no agent to keep alive.
  services.gpg-agent.enable = lib.mkForce false;
}
