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
  pkgs,
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

    # Sessions clone what a task needs into $GIT_HOME/<tool>, so git
    # needs GitHub credentials of its own: the same OpenBao-minted wrapper as
    # the operator's home (hosts/common/home.nix), resolved through THIS
    # account's Doppler service token. That token is scoped to $HOME (SETUP.md)
    # and sessions work outside it, hence the explicit --scope. The empty
    # generic helper clears the package's osxkeychain default, which would
    # otherwise persist the token.
    gh.gitCredentialHelper.enable = false;
    git.settings.credential = {
      helper = "";
      "https://github.com" = {
        helper = "!doppler run --scope $HOME -- openbao-github-creds";
        useHttpPath = true;
      };
    };

    # nix-ai enables cecli unconditionally, and its
    # tree-sitter-language-pack pin does not build on nixpkgs 26.05 — the same
    # override the operator's home carries (hosts/common/home.nix).
    cecli.enable = lib.mkForce false;

    # This account drives coding agents; it does not serve models. nix-ai
    # enables the local inference server by default, and its logical-role
    # assertion then has no catalog to resolve against, because the catalog is
    # populated per host in the operator's home.
    mlx.enable = lib.mkForce false;

    # herdr's launchd agent targets the gui/<uid> domain, which this account
    # does not have. `launchctl bootstrap` there returns "Domain does not
    # support specified action" and home-manager activation logs a failure.
    herdr.enable = lib.mkForce false;
  };

  # Same gui/<uid> domain problem as herdr. Nothing signs commits from this
  # account, so there is no agent to keep alive.
  services.gpg-agent.enable = lib.mkForce false;

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  # Upstream: https://github.com/nix-community/home-manager/issues/7935
  # TODO: Re-enable when upstream fixes options.json context in manual.nix
  manual.manpages.enable = false;

  # The sudoers grant in modules/darwin/agent-identity.nix names a flake in
  # this account's own checkout; keep that checkout present and current.
  home.activation.agentCheckout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    checkout="$HOME/${userConfig.agentUsers.claude.checkout}"
    if [ ! -d "$checkout/.git" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$checkout")"
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone --quiet https://github.com/dryvist/nix-darwin.git "$checkout" \
        || echo "[WARN] agent checkout clone failed" >&2
    else
      $DRY_RUN_CMD ${pkgs.git}/bin/git -C "$checkout" fetch --quiet origin \
        || echo "[WARN] agent checkout fetch failed" >&2
    fi
    [ -d "$HOME/.doppler" ] || echo "[WARN] $HOME/.doppler is absent; see SETUP.md 'Bootstrap the automation account'" >&2
  '';
}
