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

  # The chat UI is no longer served here: the single cluster-hosted Open WebUI
  # is the only chat UI. The llm-gate below is API-only (bearer-gated MLX).
}
