# mac-studio Home Configuration
#
# User environment for the mac-studio host. Shared home config (monitoring, zsh
# keychain/token init, copyApps, MLX, OrbStack wiring) lives in ../common/home.nix.
# Headless server: no host-specific GUI app list — `home-profile.preset = server`
# (from the registry class) already drops the GUI/desktop features.

{
  hostConfig,
  lib,
  osConfig,
  ...
}:

{
  imports = [ ../common/home.nix ];

  # Token Meter (nix-ai home-manager module) — this host only supplies
  # parameters. The gate's LAN address is read from the darwin-level llm-gate,
  # which already pins its listeners to this host's fixed reservation: Caddy's
  # `bind` needs a socket address, and a second literal is a second thing to
  # move when the reservation does.
  programs.token-meter = {
    enable = lib.mkDefault hostConfig.aiTooling.tokenMeter.enable;
    menuBar = lib.mkDefault hostConfig.aiTooling.tokenMeter.menuBar;
    httpsGate = lib.mkDefault hostConfig.aiTooling.tokenMeter.httpsGate;
    bindAddress = lib.head osConfig.programs.llm-gate.bindAddresses;
  };

  # Model cache uses the module default (/Volumes/HuggingFace) — identical to the
  # workstation, so no host override. The volume is created by nix-darwin
  # apfs-volumes; the CLI (HF_HOME) and this server share the one path.

  # The chat UI is no longer served here: the single cluster-hosted Open WebUI
  # is the only chat UI. The llm-gate below is API-only (bearer-gated MLX).
}
