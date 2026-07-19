# Shared home-manager configuration
#
# Imported by every host's home.nix. Holds host-agnostic user environment and
# consumes registry parameters (OTEL host.name, MLX sizing, OrbStack volume).
# Host-specific home config — the TCC-sensitive GUI app list — stays in
# hosts/<label>/home.nix.

{
  config,
  lib,
  osConfig,
  hostConfig,
  ...
}:

{
  imports = [
    # services.aiStack.defaultLocalModelId — supplied shared (non-secret model
    # id) from services-ai-stack.nix, pinned once for every host. Extracted to
    # keep files under the per-file size cap.
    ./services-ai-stack.nix
    # Disables nix-ai's auto-discovery of locally-cached HF models so the
    # registry stays at the single defaultLocalModelId entry.
    ./mlx-no-autodiscover.nix
    # Global git excludes seeded from the dryvist org-default (see module).
    ./git-global-excludes.nix
    # Ghostty terminfo (package + ~/.terminfo) — split out for the byte cap.
    ./ghostty-terminfo.nix
    # macOS-specific zsh init (keychain reads, gh-token switching, launchers) —
    # split out for the byte cap; merges into programs.zsh.
    ./zsh-macos.nix
    # Worker-side cluster-mode quiesce/restore hooks (byte cap split).
    ./cluster-quiesce.nix
    # Feeds the system-level clusterLinkPrep wired ceilings into nix-ai's
    # programs.mlx.clusterMode so the watcher/lifecycle env carries them.
    ./cluster-wired-limit.nix
  ];

  # Share system-level Homebrew taps with nix-ai's trust.json.
  # homebrew.taps entries can be strings or submodule attrsets (nix-darwin
  # normalizes to attrsets with a `name`); the nix-ai option takes strings.
  programs.ai-homebrew.trustedTaps = map (
    t: if builtins.isString t then t else t.name
  ) osConfig.homebrew.taps;

  # ==========================================================================
  # macOS Application Management (copyApps for TCC stability)
  # ==========================================================================
  # Use copyApps instead of linkApps to create REAL copies of apps at stable
  # paths in ~/Applications/Home Manager Apps/. This allows macOS TCC
  # (Transparency, Consent, Control) permissions to persist across rebuilds.
  #
  # With linkApps (default), apps symlink to /nix/store paths which change on
  # every rebuild, invalidating TCC permissions (camera, mic, screen recording).
  #
  # Trade-off: Uses more disk space (~100MB per app) but TCC permissions persist.
  #
  # See: https://github.com/nix-community/home-manager/issues/8336
  targets.darwin = {
    copyApps.enable = true;
    linkApps.enable = false;
  };

  # WORKAROUND: Disable manpage generation to suppress options.json derivation context warning
  # Upstream: https://github.com/nix-community/home-manager/issues/7935
  # TODO: Re-enable when upstream fixes options.json context in manual.nix
  manual.manpages.enable = false;

  # nix-home role preset: `workstation` enables all daily-driver GUI/desktop
  # features; `server` drops them. Driven by the host's registry `class`
  # (normalized in flake.nix mkHost, so the attr always exists).
  home-profile.preset = hostConfig.class;

  # ==========================================================================
  # Monitoring / Observability
  # ==========================================================================
  # Enable monitoring infrastructure (K8s manifests, helper scripts). The OTEL
  # resource host.name is the host's network name (single identity source).
  monitoring = {
    enable = true;
    kubernetes.enable = true;
    otel = {
      enable = true;
      # endpoint defaults to http://localhost:30317 (NodePort gRPC)
      logPrompts = true;
      logToolDetails = true;
      resourceAttributes = {
        "host.name" = hostConfig.hostName;
      };
    };
    cribl.enable = true;
  };

  programs = {
    # Claude Code config (plugin disables, MCP server overrides) moved to
    # nix-ai/modules/claude-config.nix in dryvist/nix-ai#853 — Claude config
    # doesn't belong in nix-darwin (host-specific opinion lives in nix-ai).

    # cecli (nix-ai's Aider fork) is disabled — unused, and its
    # tree-sitter-language-pack<=0.13.0 pin fails to build on nixpkgs 26.05
    # (which ships 1.4.1). mkForce overrides nix-ai's unconditional enable
    # (modules/default.nix). Re-enable in nix-ai once the dep bound is relaxed.
    cecli.enable = lib.mkForce false;

    # Local MLX inference server (vllm-mlx + llama-swap proxy on :11434).
    # Brings the existing vllm-mlx LaunchAgent under Nix management — without
    # this, the registry at services.aiStack.models is materialized to nothing
    # and llama-swap.json drifts from whatever was last activated by hand.
    # Sizing (cacheMemoryMb / prefillBatchSize) is per-host from the registry.
    # Gated on the host defining `mlx` so a non-inference host is left untouched
    # (no MLX server) rather than crashing on a missing attr.
    mlx = lib.mkIf (hostConfig ? mlx) ({ enable = true; } // hostConfig.mlx);

    # macOS-specific zsh overrides (keychain API keys, GitHub tiered-token
    # switching, custom launchers) live in ./zsh-macos.nix — split out for the
    # per-file byte cap. They merge into programs.zsh via the module system.
  };

  # ==========================================================================
  # OrbStack external-volume wiring (only when the host enables OrbStack)
  # ==========================================================================
  # Nix does NOT manage the volume contents — it only creates the symlink. The
  # volume itself is created by a launchd daemon (modules/darwin/apps/orbstack.nix).
  home = {
    file = lib.mkIf (hostConfig.orbstack.enable or false) {
      # Symlink the entire Group Container so ALL OrbStack data (Docker images,
      # containers, volumes, Linux VMs, logs) lives on the dedicated APFS volume.
      # MIGRATION: Stop OrbStack and move existing data before enabling.
      # NOTE: `ln` reports a permission error when OrbStack is running because the
      # Group Container directory is locked. This is expected — the symlink persists
      # correctly and does not need to be recreated on every rebuild.
      "Library/Group Containers/HUAQ24HBR6.dev.orbstack".source =
        config.lib.file.mkOutOfStoreSymlink "/Volumes/${hostConfig.orbstack.containerVolume}";

      # Docker daemon configuration for OrbStack: log rotation + build cache GC to
      # prevent unbounded disk growth. force = true: OrbStack pre-creates this file;
      # home-manager must overwrite it.
      ".orbstack/config/docker.json" = {
        force = true;
        text = builtins.toJSON (
          let
            logMaxFileSize = "25m";
            logMaxFiles = "25";
            keepDuration = "2160h"; # 90 days
            defaultKeepStorage = "10GB";
            sourceLocalMaxUsedSpace = "10GB";
            generalMaxUsedSpace = "20GB";
          in
          {
            log-driver = "json-file";
            log-opts = {
              max-size = logMaxFileSize;
              max-file = logMaxFiles;
            };
            builder.gc = {
              enabled = true;
              inherit defaultKeepStorage;
              policy = [
                {
                  inherit keepDuration;
                  filter = [ "type==source.local" ];
                  maxUsedSpace = sourceLocalMaxUsedSpace;
                }
                {
                  inherit keepDuration;
                  maxUsedSpace = generalMaxUsedSpace;
                }
              ];
            };
          }
        );
      };
    };

    sessionVariables = lib.mkIf (hostConfig.orbstack.enable or false) {
      # Container data on the dedicated external volume.
      CONTAINER_DATA = "/Volumes/${hostConfig.orbstack.containerVolume}";
    };
  };
}
