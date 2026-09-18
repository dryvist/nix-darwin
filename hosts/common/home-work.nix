# Home-manager configuration for the `work` automation identity (uid 507)
#
# Dedicated identity for employer and client repositories only.
# Holds its own forge authentication and runs in headless mode.
# Holds no passwordless sudo grant and no converge capability.

{
  lib,
  userConfig,
  ...
}:

{
  home-profile.preset = "server";

  programs = {
    # Ensure git signing is enabled by default with work SSH key
    git = {
      enable = true;
      signing = {
        signByDefault = true;
        key = lib.mkForce userConfig.agentUsers.work.signingKey;
      };
      settings = {
        gpg.format = lib.mkForce "ssh";
        user.signingkey = lib.mkForce userConfig.agentUsers.work.signingKey;
      };
    };

    # Same exclusions as other server identities
    cecli.enable = lib.mkForce false;
    mlx.enable = lib.mkForce false;
    herdr.enable = lib.mkForce false;

    # AI coding agents are forced off for the work account
    claude.latest.enable = lib.mkForce false;
    codex.enable = lib.mkForce false;
    opencode.enable = lib.mkForce false;
    cursor.enable = lib.mkForce false;
    qwen-code.enable = lib.mkForce false;
    antigravity-ide.enable = lib.mkForce false;
    antigravity-cli.enable = lib.mkForce false;
    fabric.enable = lib.mkForce false;
  };

  # Work identity uses SSH key signing rather than gpg-agent daemon
  services.gpg-agent.enable = lib.mkForce false;

  # Ensure ~/.ssh directory exists with private permissions (mode 0700)
  home.activation.setupWorkSsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
    $DRY_RUN_CMD chmod 0700 "$HOME/.ssh"
  '';

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  manual.manpages.enable = false;
}
