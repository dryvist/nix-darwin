# mac-studio Home Configuration
#
# User environment for the mac-studio host. Shared home config (monitoring, zsh
# keychain/token init, copyApps, MLX, OrbStack wiring) lives in ../common/home.nix.
# Headless server: no host-specific GUI app list — `home-profile.preset = server`
# (from the registry class) already drops the GUI/desktop features.

{ config, ... }:

{
  imports = [ ../common/home.nix ];

  # Model cache on the internal 4 TB SSD. The laptop's external
  # /Volumes/HuggingFace assumption (module default) is deliberately not
  # carried onto the Studio — ADR: llm-large-studio-serving.
  programs.mlx.huggingFaceHome = "${config.home.homeDirectory}/.cache/huggingface";

  # Manual-query chat UI on loopback; the llm-gate Caddy fronts it with TLS on
  # the LAN (:8443). Open WebUI keeps its own login, so no bearer on that site.
  programs.open-webui.enable = true;
}
