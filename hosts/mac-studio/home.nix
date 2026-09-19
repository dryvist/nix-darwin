# mac-studio Home Configuration
#
# User environment for the mac-studio host. Shared home config (monitoring, zsh
# keychain/token init, copyApps, MLX, OrbStack wiring) lives in ../common/home.nix.
# Headless server: no host-specific GUI app list — `home-profile.preset = server`
# (from the registry class) already drops the GUI/desktop features.

{ lib, ... }:

{
  imports = [ ../common/home.nix ];

  # This host holds an hourly one-way rsync replica of another host's
  # coding-agent transcripts (sessionSync). ../common/home.nix enables
  # programs.claudeUsageCollector on every host, so this host's collector
  # would re-read the replica and post the source host's cumulative totals a
  # second time under its own identity. mkForce disables it here; the
  # replica's owning host remains the single source for those transcripts.
  # Ceiling: any session run natively on this host goes uncollected too —
  # move the replica outside the transcript roots before re-enabling.
  programs.claudeUsageCollector.enable = lib.mkForce false;

  # Token Meter's universal service and menu-bar opt-in live in
  # ../common/home.nix. This server alone exposes the optional HTTPS gate.
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
    httpsGate = true;
    bindAddress = "0.0.0.0";
  };

  # Model cache uses the module default (/Volumes/HuggingFace) — identical to the
  # workstation, so no host override. The volume is created by nix-darwin
  # apfs-volumes; the CLI (HF_HOME) and this server share the one path.

  # The chat UI is no longer served here: the single cluster-hosted Open WebUI
  # is the only chat UI. The llm-gate below is API-only (bearer-gated MLX).
}
