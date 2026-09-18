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
  pkgs,
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
    # open-llm holds no signing key and never commits locally — its
    # commits are made through the GitHub API as its App and show Verified.
    git = {
      enable = true;
      signing.signByDefault = true;
    };

    # One provider per endpoint, each reading its own env key so model choice
    # follows key choice injected at launch by openbao-run.
    opencode.extraSettings = {
      provider = {
        openrouter = {
          npm = "@ai-sdk/openai-compatible";
          name = "OpenRouter";
          options = {
            baseURL = "https://openrouter.ai/api/v1";
            apiKey = "{env:OPENROUTER_API_KEY}";
          };
        };
        zai = {
          npm = "@ai-sdk/openai-compatible";
          name = "Z.ai";
          options = {
            baseURL = "https://api.z.ai/api/paas/v4";
            apiKey = "{env:ZAI_API_KEY}";
          };
        };
        litellm = {
          npm = "@ai-sdk/openai-compatible";
          name = "LiteLLM (local)";
          options = {
            baseURL = "http://127.0.0.1:4000/v1";
            apiKey = "{env:LITELLM_LOCAL_KEY}";
          };
        };
      };
    };

    # Shell alias to route opencode through openbao-run
    zsh.shellAliases = {
      opencode = "opencode-openbao";
    };
  };

  # opencode launcher injecting provider keys from OpenBao into memory env only.
  # Fails closed if openbao-run is unavailable, preventing unauthenticated execution.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "opencode-openbao";
      runtimeInputs = [ ];
      text = ''
        if ! command -v openbao-run >/dev/null 2>&1; then
          echo "[opencode-openbao] Fatal: openbao-run not found. Failing closed to prevent unauthenticated execution." >&2
          exit 1
        fi
        exec openbao-run --domain ai-public \
          --secret OPENROUTER_API_KEY=ai/public#OPENROUTER_API_KEY \
          --secret ZAI_API_KEY=ai/public#ZAI_API_KEY \
          --secret LITELLM_LOCAL_KEY=ai/public#LITELLM_LOCAL_KEY \
          -- opencode "$@"
      '';
    })
  ];

  # Same gui/<uid> domain problem as herdr. Nothing signs commits from this
  # account, so there is no agent to keep alive.
  services.gpg-agent.enable = lib.mkForce false;

  # Ensure ~/.doppler is completely absent from the untrusted tier
  home.activation.removeDoppler = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -e "$HOME/.doppler" ]; then
      $DRY_RUN_CMD rm -rf "$HOME/.doppler"
    fi
  '';

  # Replace Claude-only @import syntax by generated concatenation so OpenCode
  # receives the complete instruction context in a single document
  home.activation.generateInstructionBundle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/.agents/AGENTS.md" ]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.config/opencode"
      $DRY_RUN_CMD ${pkgs.python3}/bin/python3 \
        ${../../modules/darwin/apps/scripts/generate-instruction-bundle.py} \
        "$HOME/.agents/AGENTS.md" \
        "$HOME/.config/opencode/AGENTS.md" \
        "$HOME/.agents/agentsmd/rules" || true
    fi
  '';

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  # Upstream: https://github.com/nix-community/home-manager/issues/7935
  # TODO: Re-enable when upstream fixes options.json context in manual.nix
  manual.manpages.enable = false;
}
