# macbook-m4 Home Configuration
#
# User environment for the macbook-m4 host. Shared home config (monitoring, zsh
# keychain/token init, copyApps, MLX, OrbStack wiring) lives in ../common/home.nix.
# This file adds only the host-unique bits — the TCC-sensitive GUI app list.

{
  lib,
  pkgs,
  userConfig,
  ...
}:

{
  imports = [ ../common/home.nix ];

  # This host receives the router bearer from its launch environment.
  services.aiStack = {
    llmEndpointBearerFromEnv = true;
  };

  # Open local-LLM fallback harness (Crush / MiMoCode / Goose). Workstation-only:
  # flake.nix imports the module on macbook-m4 alone. The runtime bearer token
  # OPENAI_API_KEY is exported from the automation keychain in ../common/home.nix
  # (alongside HF_TOKEN etc.), so this host only names the endpoint.
  #
  # The router is an internal service, so its FQDN composes from
  # userConfig.internalDomain. Composing it from the public apex instead yields
  # a name with no DNS record, which every harness surfaces as a connection
  # failure rather than as a configuration error.
  programs = {
    openwhispr = {
      enable = true;
      autoStart = false; # launch by hand only
      modelBootstrap = true;
      localTranscriptionProvider = "whisper";
      whisperModel = "base";
    };

    openHarness = {
      enable = true;
      endpoint = "https://llm.${userConfig.internalDomain}/v1";
      # Upstream mimo-code release asset returns 404; the package fails to build.
      mimoCode.enable = false;
    };

    # Daily push of AI session history to the per-vendor object buckets
    # (nix-ai module) — the durable off-Mac copy. Runs as a launchd
    # agent on purpose: agents carry no GUI responsible app, so macOS Local
    # Network gating never applies to them, where the same push from a
    # terminal-descended shell breaks whenever en0 wakes up on the storage
    # subnet (probe-verified). Credentials are the ai-sessions-backup AppRole,
    # injected per run; nothing is stored on this machine.
    sessionArchive = {
      enable = true;
      endpoint = "https://s3.${userConfig.internalDomain}";
    };

  };

  # Nothing session- or audit-related starts on its own on this host.
  launchd.agents = {
    herdr.enable = lib.mkForce false;
    ai-stack-drift-check.enable = lib.mkForce false;
  };

  # ==========================================================================
  # TCC-Sensitive GUI Applications (using copyApps for stable paths)
  # ==========================================================================
  # These apps need macOS TCC (Transparency Consent Control) permissions for
  # camera, microphone, screen recording, etc. With targets.darwin.copyApps
  # enabled (../common/home.nix), apps in home.packages are COPIED to
  # ~/Applications/Home Manager Apps/ with STABLE paths that persist TCC
  # permissions across darwin-rebuild (better than mac-app-util trampolines:
  # stable binary paths, no wrapper scripts). Trade-off: ~100MB per app.
  #
  # Workstation-only: a headless host drops these.
  home.packages = with pkgs; [
    # Terminal & Development
    # ghostty: moved to homebrew.nix cask (greedy). It is the ONE app whose TCC
    # grants block work when they lapse — it is the terminal every agent session
    # and every darwin-rebuild runs inside, so losing Full Disk Access there
    # stops the machine being manageable until a human re-grants it by hand.
    #
    # copyApps was not enough. It gives a stable PATH, and Ghostty is properly
    # Developer ID signed (Mitchell Hashimoto, 24VZTF6M5V, hardened runtime), so
    # neither of the usual nix causes applies. But activation REPLACES the bundle
    # wholesale — verified 2026-07-29, every app under ~/Applications/Home Manager
    # Apps/ carrying the same rewrite timestamp — and a delete-and-recreate at a
    # stable path is still a new bundle to TCC. A cask is a real /Applications
    # copy that Homebrew upgrades IN PLACE, which is the same reason OrbStack
    # already lives there (see hosts/common/default.nix).
    #
    # ghostty-bin.terminfo stays a nix package (hosts/common/ghostty-terminfo.nix):
    # it is terminfo data, not an app, nothing about it is TCC-sensitive, and
    # servers need it without the GUI.
    rapidapi # Full-featured HTTP client for testing and describing APIs (sandboxed — auto-update prevention not possible)

    # AI IDEs & Tools (nixpkgs - stable TCC paths via copyApps)
    code-cursor # Cursor AI IDE (VS Code fork)
    # chatgpt: moved to homebrew.nix cask (greedy). nixpkgs lags OpenAI's
    # weekly releases by months and a store app cannot self-update; the
    # greedy cask mirrors the `claude` desktop pattern and stays current.

    # Communication
    discord # Voice/video chat - copyApps gives TCC-stable path for camera/mic permissions
    # zoom-us # DISABLED - no longer using Zoom

    # Productivity / menu bar
    # raycast: moved to homebrew.nix cask (greedy) — nixpkgs lags upstream.
    swiftbar # Menu bar customization

    # CLI / Media tools (non-GUI, no .app bundle)
    ffmpeg # Complete solution to record, convert and stream audio and video
    d2 # D2 diagram compiler — kept on PATH for the Cursor D2 extension's live
    # preview (elsewhere it's on-demand only via `nix run nixpkgs#d2`)
  ];
}
