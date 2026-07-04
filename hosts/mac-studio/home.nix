# mac-studio Home Configuration
#
# User environment for the mac-studio host. Shared home config (monitoring, zsh
# keychain/token init, copyApps, MLX, OrbStack wiring) lives in ../common/home.nix.
# Headless server: no host-specific GUI app list — `home-profile.preset = server`
# (from the registry class) already drops the GUI/desktop features.

{ config, ... }:

{
  imports = [ ../common/home.nix ];

  # Model cache on the dedicated /Volumes/HuggingFace APFS volume, matching the
  # workstation and the module default. The volume is created by nix-darwin
  # apfs-volumes; the CLI (HF_HOME) and this server now share one path.
  programs.mlx.huggingFaceHome = "/Volumes/HuggingFace";

  # The chat UI is no longer served here: the single cluster-hosted Open WebUI
  # is the only chat UI. The llm-gate below is API-only (bearer-gated MLX).
}
