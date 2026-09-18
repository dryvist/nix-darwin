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
    # Ensure git signing is enabled by default
    git = {
      enable = true;
      signing.signByDefault = true;
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

  # Work identity does not run ambient gpg-agent daemon
  services.gpg-agent.enable = lib.mkForce false;

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  manual.manpages.enable = false;
}
