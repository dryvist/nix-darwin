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
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

{
  home-profile.preset = "server";

  # open-llm is a lower-trust identity running opencode/cursor.
  # It must NOT have access to Doppler or secret management CLIs.
  # Blocked packages: doppler, openbao (bao), bitwarden-cli (bw), bws.
  home = {
    # 1. Filter secret-management CLIs out of home-manager-path.
    # These arrive unconditionally from nix-home (security.nix) and nix-ai
    # (ai-tools.nix) via sharedModules; filtering here is the only lever
    # inside nix-darwin without modifying those upstream repos.
    path = lib.mkForce (
      let
        # Package names to exclude from the lower-trust profile.
        blocked = [
          "doppler"
          "openbao"
          "bitwarden-cli"
          "bws"
        ];
      in
      pkgs.buildEnv {
        name = "home-manager-path";
        paths = builtins.filter (
          p:
          let
            name = p.pname or p.name or "";
          in
          !builtins.elem name blocked && !(lib.hasPrefix "doppler-" name)
        ) config.home.packages;
        inherit (config.home) extraOutputsToInstall;
        postBuild = config.home.extraProfileCommands;
        meta = {
          description = "Environment of packages for ${config.home.username}";
        };
      }
    );

    # 2. Defense in depth: strip secret-management binaries from profile outputs.
    extraProfileCommands = ''
      rm -f $out/bin/doppler $out/bin/bao $out/bin/bw $out/bin/bws
    '';

    # 3. Purge any leftover credential directories from this account's home:
    activation.removeDoppler = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for dir in "$HOME/.doppler" "$HOME/.bw" "$HOME/.config/bws"; do
        if [ -d "$dir" ]; then
          $DRY_RUN_CMD rm -rf "$dir"
        fi
      done
    '';
  };

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

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  # Upstream: https://github.com/nix-community/home-manager/issues/7935
  # TODO: Re-enable when upstream fixes options.json context in manual.nix
  manual.manpages.enable = false;
}
