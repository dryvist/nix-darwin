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
  pkgs,
  hostConfig,
  nix-ai,
  ...
}:
let
  # See the script's own header for why this is an activation step and not a
  # home.file entry. Short version: home.file re-links every generation, and a
  # write into ~/Library/Group Containers hangs rather than fails, which wedged
  # activation and silently skipped everything after it.
  orbstackLinkPkg = pkgs.writeShellApplication {
    name = "link-orbstack-container";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv.ORBSTACK_CONTAINER_VOLUME = hostConfig.orbstack.containerVolume or "";
    text = builtins.readFile ./scripts/link-orbstack-container.sh;
  };

  # The CPython minor the MLX cluster rank's `uv run --python <ver>` actually
  # requests. Read directly from nix-ai's own lib/python.nix (the flake input,
  # not a re-declared literal) so this can never drift from the value nix-ai's
  # mlx module uses to build the rank's launch command — that repo owns the
  # pin, this repo only needs to know it to scope the signing glob below.
  # Deliberately the MINOR only ("3.14"): the launch command passes exactly
  # that to uv, and uv — not nix — resolves and owns the installed patch
  # (3.14.6 today), so the glob still wildcards the patch component.
  mlxRankPythonVersion = (import "${nix-ai}/lib/python.nix" { inherit pkgs; }).pythonVersion;
in
{
  imports = [
    # Leaves services.aiStack.defaultLocalModelId empty; MLX hosts populate
    # every logical role through catalog selections.
    ./services-ai-stack.nix
    # Disables nix-ai's auto-discovery of locally-cached HF models so the
    # registry contains only catalog-declared models and roles.
    ./mlx-no-autodiscover.nix
    # Global git excludes seeded from the dryvist org-default (see module).
    ./git-global-excludes.nix
    ./agent-skills.nix
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
    ./residency-budget.nix
    # Durable code-signing identity for the cluster executables, so their macOS
    # privacy grants survive a rebuild instead of dying with the store path.
    ./mlx-cluster-signing.nix
  ];

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
    # Share system-level Homebrew taps with nix-ai's trust.json.
    # homebrew.taps entries can be strings or submodule attrsets (nix-darwin
    # normalizes to attrsets with a `name`); the nix-ai option takes strings.
    ai-homebrew.trustedTaps = map (t: if builtins.isString t then t else t.name) osConfig.homebrew.taps;

    # --- GitHub credentials for git: OpenBao-minted, never keychain ---
    # git resolves GitHub HTTPS credentials through the OpenBao-backed wrapper
    # (modules/darwin/apps/openbao-github-creds.nix): ambient READ tokens per
    # owner, write only behind `openbao-github-creds claim`. `doppler run`
    # supplies the wrapper's secret-zero ambiently; useHttpPath makes git send
    # path=<owner>/<repo> so the wrapper picks the right read set. gh's own
    # git credential helper is disabled so the wrapper is the ONLY GitHub
    # credential path for git — a push without a claim fails loud at GitHub
    # (read token, 403) instead of silently riding a broader credential.
    gh.gitCredentialHelper.enable = false;
    git.settings.credential = {
      # nixpkgs' git ships `credential.helper = osxkeychain` in the package's
      # own /etc/gitconfig. That generic helper is consulted BEFORE the
      # url-scoped ones below, and its `store` action writes every credential
      # git sees into login.keychain — so an OpenBao-minted token stops being
      # ephemeral the moment it is used, and a stale long-lived token in the
      # keychain wins over the wrapper. An empty value resets the helper list,
      # and ~/.config/git/config is read after the package gitconfig, so this
      # clears it. Leaves the url-scoped helpers (a separate list) intact.
      helper = "";
      "https://github.com" = {
        helper = "!doppler run -- openbao-github-creds";
        useHttpPath = true;
      };
      "https://gist.github.com" = {
        helper = "!doppler run -- openbao-github-creds";
        useHttpPath = true;
      };
    };

    # Claude Code config (plugin disables, MCP server overrides) moved to
    # nix-ai/modules/claude-config.nix in dryvist/nix-ai#853 — Claude config
    # doesn't belong in nix-darwin (host-specific opinion lives in nix-ai).

    # The canonical AI MCP registry renders the same enabled server set for
    # Claude, Codex, and the other local clients on every host. Vikunja's
    # credentials remain injected by the shared Doppler wrapper.
    aiMcp.servers.vikunja.disabled = lib.mkForce false;
    aiMcp.servers.openwhispr.disabled = lib.mkForce false;

    # cecli (nix-ai's Aider fork) is disabled — unused, and its
    # tree-sitter-language-pack<=0.13.0 pin fails to build on nixpkgs 26.05
    # (which ships 1.4.1). mkForce overrides nix-ai's unconditional enable
    # (modules/default.nix). Re-enable in nix-ai once the dep bound is relaxed.
    cecli.enable = lib.mkForce false;

    # Local MLX inference server (mlx_lm + llama-swap proxy on :11434).
    # Brings the MLX model-server LaunchAgent under Nix management — without
    # this, the registry at services.aiStack.models is materialized to nothing
    # and llama-swap.json drifts from whatever was last activated by hand.
    # Sizing (cacheMemoryMb / prefillBatchSize) is per-host from the registry.
    # Gated on the host defining `mlx` so a non-inference host is left untouched
    # (no MLX server) rather than crashing on a missing attr.
    mlx = lib.mkIf (hostConfig ? mlx) ({ enable = true; } // hostConfig.mlx);

    # macOS-specific zsh overrides (keychain API keys, GitHub tiered-token
    # switching, custom launchers) live in ./zsh-macos.nix — split out for the
    # per-file byte cap. They merge into programs.zsh via the module system.

    # Only meaningful on hosts running cluster ranks. Measured live: the
    # rank's ephemeral uv interpreter resolves via symlink to this exact
    # path, so signing it in place reaches what actually runs. Glob scoped
    # to the one CPython minor nix-ai actually requests (mlxRankPythonVersion
    # above) — `cpython-*`/`python3*` previously matched every cached
    # version (five, measured) plus every `*-config` script. Keep
    # "rank-python" unchanged: renaming voids any existing grant. sweepRoots
    # un-brands whatever the glob no longer matches (see that option's doc).
    mlxClusterSigning = lib.mkIf (hostConfig ? mlx) {
      enable = true;
      signInPlace = {
        rank-python = "${config.home.homeDirectory}/.local/share/uv/python/cpython-${mlxRankPythonVersion}.*-macos-aarch64-none/bin/python${mlxRankPythonVersion}";
      };
      sweepRoots = [ "${config.home.homeDirectory}/.local/share/uv/python" ];
    };

    # VisiCore operator CLIs — workstation-only. Set unconditionally so a
    # nix-ai lock predating the option fails the build instead of quietly
    # dropping the feature.
    vctCli.enable = !hostConfig.isServer;
  };

  # ==========================================================================
  # OrbStack external-volume wiring (only when the host enables OrbStack)
  # ==========================================================================
  # Nix does NOT manage the volume contents — it only creates the symlink. The
  # volume itself is created by a launchd daemon (modules/darwin/apps/orbstack.nix).
  home = {
    file = lib.mkIf (hostConfig.orbstack.enable or false) {
      # The Group Container symlink is deliberately NOT here — see
      # `linkOrbstackContainer` below. home.file re-links every managed path on
      # every generation, and a write into ~/Library/Group Containers does not
      # fail on this machine, it HANGS, which wedges activation.

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

    activation = lib.mkIf (hostConfig.orbstack.enable or false) {
      linkOrbstackContainer = lib.hm.dag.entryAfter [
        "writeBoundary"
      ] "${orbstackLinkPkg}/bin/link-orbstack-container";
    };
  };
}
