# mac-studio Home Configuration
#
# User environment for the mac-studio host. Shared home config (monitoring, zsh
# keychain/token init, copyApps, MLX, OrbStack wiring) lives in ../common/home.nix.
# Headless server: no host-specific GUI app list — `home-profile.preset = server`
# (from the registry class) already drops the GUI/desktop features.

{
  config,
  osConfig,
  ...
}:

{
  imports = [ ../common/home.nix ];

  # The local proxy's launch wrapper injects the router bearer as OPENAI_API_KEY;
  # no token file is read.
  services.aiStack.llmEndpointBearerFromEnv = true;

  # Server-room wall monitor: never let the screensaver engage. idleTime is a
  # ByHost preference (currentHostDefaults writes it via `defaults
  # -currentHost`, as this user, no activation script needed).
  targets.darwin.currentHostDefaults."com.apple.screensaver".idleTime = 0;

  programs = {
    mlx.modelAdmissionLimits =
      let
        roleModels = config.programs.mlx.roleMap.models;
        admissionLimit = osConfig.programs.llm-gate.apiMaxUpstreamConnections;
      in
      {
        ${roleModels.qwen38-27b.id} = admissionLimit;
        ${roleModels.mimo-9b.id} = admissionLimit;
      };

    # Master sessions run here on a 1M-token window and compact near 85% of it.
    claude.settings = {
      autoCompactThresholdPercent = 85;
      env.CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000";
    };

    litellmLocal = {
      enable = true;
    };

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
    token-meter = {
      httpsGate = true;
      bindAddress = "0.0.0.0";
    };
  };

  # Model cache uses the module default (/Volumes/HuggingFace) — identical to the
  # workstation, so no host override. The volume is created by nix-darwin
  # apfs-volumes; the CLI (HF_HOME) and this server share the one path.

  # The chat UI is no longer served here: the single cluster-hosted Open WebUI
  # is the only chat UI. The llm-gate below is API-only (bearer-gated MLX).
}
