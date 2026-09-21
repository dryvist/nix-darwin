# Home-manager configuration for the `open-llm` automation identity
#
# The second dedicated agent account (see modules/darwin/agent-identity.nix).
# Full parity with the `claude` identity (hosts/common/home-agent.nix): same
# headless `server` preset, same launchd-domain exclusions, and every coding
# agent nix-ai enables by default stays on — including `claude` itself, run
# against Z.ai's endpoint via the `zcode` function below instead of a
# first-party Anthropic subscription. `converge = false` in lib/user-config.nix
# means this account never gets the agent-identity.nix sudoers grant, so it
# has the same tools as `claude` but none of its host-rebuild privilege.
#
# UNLIKE `claude`: this identity holds no Doppler service token (operator
# decision — open-llm is not trusted with Doppler at all). nix-ai's
# `claude-zai` (modules/ai-aliases.zsh) now uses an already-set
# ZAI_SUBSCRIPTION_KEY as-is and only falls back to `doppler run` when it is
# unset — so `zcode` just has to set that env var and call the SAME function,
# rather than re-implement its ANTHROPIC_*/model wiring here. `openbao-run`
# (modules/darwin/scripts/openbao-run.sh) fetches the key from OpenBao
# (roles/openbao/templates/open-llm-policy.hcl.j2 in ansible-proxmox-apps,
# secret/apps/open-llm#ZAI_SUBSCRIPTION_KEY); secret-zero (BAO_ADDR + the
# open-llm AppRole's role_id/secret_id) lives in a 0600 env file under this
# account's own home, never in this repo. `-ic` re-sources zshrc in the
# exec'd child so the `claude-zai` function (defined there) exists to call.

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
    # the `claude` identity.
    zsh.initContent = lib.mkAfter ''
      zcode() {
        openbao-run --domain open-llm \
          --env-file "$HOME/.config/openbao/open-llm.env" \
          --secrets apps/open-llm \
          -- zsh -ic 'claude-zai "$@"' zsh "$@"
      }
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
