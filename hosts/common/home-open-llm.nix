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
# decision — open-llm is not trusted with Doppler at all), so it cannot use
# nix-ai's `claude-zai` alias, which fetches ZAI_SUBSCRIPTION_KEY via
# `doppler run`. `zcode` below is its own function, reading the same key from
# OpenBao instead (roles/openbao/templates/open-llm-policy.hcl.j2 in
# ansible-proxmox-apps, secret/apps/open-llm#ZAI_SUBSCRIPTION_KEY) via the
# existing `openbao-run` helper (modules/darwin/scripts/openbao-run.sh) —
# secret-zero (BAO_ADDR + the open-llm AppRole's role_id/secret_id) lives in
# a 0600 env file under this account's own home, never in this repo. It then
# execs `claude` with the same ANTHROPIC_*/model env wiring claude-zai uses,
# so it is a drop-in behavioral match, just with a different secret source.

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
    # the `claude` identity. ZAI_CLAUDE_BASE_URL/PRIMARY_MODEL/FAST_MODEL/
    # AUTO_COMPACT_WINDOW are non-secret config, already exported ambiently
    # by nix-ai's ai-shell.nix for every account (including this one) — only
    # the subscription key is a secret, and that is the one thing this
    # function fetches, from OpenBao rather than Doppler.
    zsh.initContent = lib.mkAfter ''
      zcode() {
        openbao-run --domain open-llm \
          --env-file "$HOME/.config/openbao/open-llm.env" \
          --secrets apps/open-llm \
          -- zsh -c '
            ANTHROPIC_API_KEY= \
            ANTHROPIC_AUTH_TOKEN="$ZAI_SUBSCRIPTION_KEY" \
            ANTHROPIC_BASE_URL="$ZAI_CLAUDE_BASE_URL" \
            ANTHROPIC_CUSTOM_HEADERS= \
            CLAUDE_CODE_OAUTH_TOKEN= \
            CLAUDE_CODE_USE_BEDROCK= \
            CLAUDE_CODE_USE_VERTEX= \
            OPENAI_API_KEY= \
            ANTHROPIC_DEFAULT_FABLE_MODEL="$ZAI_CLAUDE_PRIMARY_MODEL" \
            ANTHROPIC_DEFAULT_OPUS_MODEL="$ZAI_CLAUDE_PRIMARY_MODEL" \
            ANTHROPIC_DEFAULT_SONNET_MODEL="$ZAI_CLAUDE_FAST_MODEL" \
            ANTHROPIC_DEFAULT_HAIKU_MODEL="$ZAI_CLAUDE_FAST_MODEL" \
            CLAUDE_CODE_SUBAGENT_MODEL="$ZAI_CLAUDE_FAST_MODEL" \
            CLAUDE_CODE_AUTO_COMPACT_WINDOW="$ZAI_CLAUDE_AUTO_COMPACT_WINDOW" \
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
            API_TIMEOUT_MS=3000000 \
              exec claude "$@"
          ' zsh "$@"
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
