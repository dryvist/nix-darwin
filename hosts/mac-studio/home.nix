# mac-studio Home Configuration
#
# User environment for the mac-studio host. Shared home config (monitoring, zsh
# keychain/token init, copyApps, MLX, OrbStack wiring) lives in ../common/home.nix.
# Headless server: no host-specific GUI app list — `home-profile.preset = server`
# (from the registry class) already drops the GUI/desktop features.

{
  hostConfig,
  lib,
  ...
}:

{
  imports = [ ../common/home.nix ];

  # Token Meter (nix-ai home-manager module) — this host only supplies
  # parameters.
  #
  # Its HTTPS gate listens on all interfaces, matching llm-gate, with the
  # firewall as the boundary.
  #
  # bindAddress used to borrow llm-gate's pinned address. llm-gate no longer
  # pins one, so there is nothing to borrow, and this is set explicitly rather
  # than re-coupled. The module asserts a non-empty bindAddress whenever the
  # gate is on — that check is left intact and satisfied with the
  # all-interfaces address, so an accidental empty value still fails loudly.
  programs.token-meter = {
    enable = lib.mkDefault hostConfig.aiTooling.tokenMeter.enable;
    menuBar = lib.mkDefault hostConfig.aiTooling.tokenMeter.menuBar;
    httpsGate = lib.mkDefault hostConfig.aiTooling.tokenMeter.httpsGate;
    bindAddress = "0.0.0.0";
  };

  # Model cache uses the module default (/Volumes/HuggingFace) — identical to the
  # workstation, so no host override. The volume is created by nix-darwin
  # apfs-volumes; the CLI (HF_HOME) and this server share the one path.

  # The chat UI is no longer served here: the single cluster-hosted Open WebUI
  # is the only chat UI. The llm-gate below is API-only (bearer-gated MLX).
}
