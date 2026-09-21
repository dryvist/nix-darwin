# Home-manager configuration for the `open-llm` automation identity
#
# The second dedicated agent account (see modules/darwin/agent-identity.nix).
# Full parity with the `claude` identity (hosts/common/home-agent.nix): same
# headless `server` preset, same launchd-domain exclusions, and every coding
# agent nix-ai enables by default stays on — including `claude` itself, run
# against Z.ai's endpoint via the `zcode` alias below instead of a first-party
# Anthropic subscription. `converge = false` in lib/user-config.nix means this
# account never gets the agent-identity.nix sudoers grant, so it has the same
# tools as `claude` but none of its host-rebuild privilege.

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

    # `claude`, `codex`, `qwen-code`, `antigravity-*`, `cursor`, `opencode`,
    # and `fabric` all stay at their nix-ai default (on) — same tool set as
    # the `claude` identity. `claude-zai`/`codex-zai` (nix-ai
    # modules/ai-shell.nix, modules/ai-aliases.zsh) already point either CLI
    # at Z.ai's endpoint using a Doppler-sourced ZAI_SUBSCRIPTION_KEY; `zcode`
    # is just this account's name for that existing launcher, not a new tool.
    zsh.initContent = lib.mkAfter ''
      alias zcode=claude-zai
    '';
  };

  # Same gui/<uid> domain problem as herdr. Nothing signs commits from this
  # account with a GUI-backed key; its git identity/signing is provisioned
  # separately (see SETUP.md).
  services.gpg-agent.enable = lib.mkForce false;

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  # Upstream: https://github.com/nix-community/home-manager/issues/7935
  # TODO: Re-enable when upstream fixes options.json context in manual.nix
  manual.manpages.enable = false;
}
