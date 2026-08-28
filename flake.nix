{
  # Nix-darwin flake configuration
  description = "nix-darwin configuration for M4 Max MacBook Pro";

  inputs = {
    # Channel branch = intended major-version pin (26.05, stable). Renovate
    # CANNOT bump this: it updates an input when its ref changes, and a
    # channel branch's ref never changes. deps-flake-lock.yml relocks the whole
    # file on a schedule instead.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    # Consolidated systems input for darwin-only configuration
    # All transitive dependencies should follow this to avoid duplicate systems entries
    systems.url = "github:nix-systems/default-darwin";

    # Using stable nix-darwin-26.05 to match nixpkgs
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Using stable home-manager release-26.05 to match nixpkgs
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Direct inputs for independent updating (follows into nix-ai)
    # These are non-flake repos — zero transitive deps, always a 6-line flake.lock diff
    jacobpevans-cc-plugins = {
      url = "github:dryvist/claude-code-plugins";
      flake = false;
    };
    ai-assistant-instructions = {
      url = "github:dryvist/ai-assistant-instructions";
      flake = false;
    };
    ai-llm-prompts = {
      url = "github:dryvist/ai-llm-prompts/30551ed25e5ee4831389fe11f55849e25bceee3f";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-plugins = {
      url = "github:anthropics/claude-code";
      flake = false;
    };
    # dryvist org-wide config hub. Source of the org-default .gitignore
    # (configs/gitignore) that seeds the global git excludes file. Tracks
    # main; `nix flake update dotgithub` pulls the latest. The git module
    # tolerates the file being absent (pre-merge) and activates once present.
    dotgithub = {
      url = "github:dryvist/.github";
      flake = false;
    };

    # AI CLI ecosystem (Claude, Gemini, Copilot, MCP, marketplace).
    # Only AI flake nix-darwin imports — Claude/Gemini/Codex/MCP config
    # all flow through nix-ai. nix-claude-code is consumed transitively
    # via nix-ai (kept off nix-darwin's top-level inputs to avoid pulling
    # 24 marketplace inputs + nix-devenv dev-tooling into our lock).
    nix-ai = {
      # git-flow default is develop; pin main so we track releases, not it.
      url = "github:dryvist/nix-ai/main";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        ai-assistant-instructions.follows = "ai-assistant-instructions";
        ai-llm-prompts.follows = "ai-llm-prompts";
        claude-code-plugins.follows = "claude-code-plugins";
        jacobpevans-cc-plugins.follows = "jacobpevans-cc-plugins";
      };
    };

    # Focused fallback harness for open/local-LLM agent CLIs (Crush + MiMoCode).
    # Enabled only on workstation hosts that explicitly import the module below.
    nix-ai-open-harness = {
      url = "github:dryvist/nix-ai-open-harness";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # Cross-platform home-manager modules (git, zsh, vscode, monitoring, shells)
    nix-home = {
      url = "github:dryvist/nix-home";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-openwhispr = {
      url = "github:dryvist/nix-openwhispr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Official Determinate Nix module; automated updates are tracked by Renovate.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    # Legacy bridge while remaining consumers move to OpenBao.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew owns /opt/homebrew; brew-src tracks the current cask DSL.
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    brew-src = {
      url = "github:Homebrew/brew/master";
      flake = false;
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      darwin,
      home-manager,
      nix-ai,
      nix-ai-open-harness,
      nix-openwhispr,
      nix-home,
      determinate,
      sops-nix,
      nix-homebrew,
      dotgithub,
      ...
    }:
    let
      userConfig = import ./lib/user-config.nix;
      hosts = import ./lib/hosts.nix;
      hostProfiles = import ./lib/host-profiles.nix { inherit lib; };
      hmDefaults = import ./lib/home-manager-defaults.nix;
      inherit (nixpkgs) lib;

      # Guard: fail at eval time if stateVersion drifts from nixpkgs branch.
      # When Renovate bumps nixpkgs-26.05 → nixpkgs-26.11, this assertion fires
      # with a clear message — the fix is to update lib/user-config.nix.
      _stateVersionCheck =
        let
          expected = "26.05"; # must match nixpkgs URL: nixpkgs-26.05-darwin
          actual = userConfig.nix.homeManagerStateVersion;
        in
        assert
          expected == actual
          || builtins.throw ''
            homeManagerStateVersion mismatch: expected "${expected}" (from nixpkgs branch) but got "${actual}".
            Update lib/user-config.nix when bumping nixpkgs.
          '';
        true;

      # Build one darwinSystem per registry entry. `label` is the hosts/<label>/
      # folder; the resulting config is exposed under `host.hostName` (below).
      mkHost =
        label: host:
        assert _stateVersionCheck;
        let
          # Normalize and inject the host capability profile once.
          class = host.class or "workstation";
          hostProfile =
            if builtins.hasAttr class hostProfiles then
              hostProfiles.${class}
            else
              builtins.throw "Unknown host profile: ${class}";
          hostConfig = lib.recursiveUpdate hostProfile (
            host
            // {
              inherit class;
              isServer = class == "server";
            }
          );
          # Telemetry resource attributes are the one part of userConfig that is
          # host-specific: without host.name every Mac reporting to the shared
          # collector is indistinguishable in the backend.
          hostUserConfig = userConfig // {
            telemetry = (userConfig.telemetry or { }) // {
              resourceAttributes = (userConfig.telemetry.resourceAttributes or { }) // {
                "host.name" = hostConfig.hostName;
              };
            };
          };
        in
        darwin.lib.darwinSystem {
          # nix-darwin is Darwin-only and every host is Apple Silicon, so the
          # registry omits `system`; default it here (overridable for an Intel host).
          system = host.system or "aarch64-darwin";
          # nix-ai maps the default-off capabilities to Homebrew packages.
          specialArgs = {
            inherit
              nix-ai
              hostConfig
              nix-homebrew
              ;
          };
          modules = [
            ./hosts/${label}/default.nix

            # Stamp every generation with the source commit so cross-host
            # generation parity is checkable (cluster-join step-0 preflight
            # compares darwin-version's configurationRevision to the deploy
            # branch HEAD). Dirty builds stamp null and fail that preflight
            # closed by design.
            { system.configurationRevision = self.rev or null; }

            # Determinate Nix: official module for nix.conf, GC, and determinate-nixd config
            determinate.darwinModules.default

            # Legacy SOPS bridge while remaining consumers move to OpenBao.
            sops-nix.darwinModules.sops

            # Python package overlay from nix-home (replaces local overlays/python-packages.nix)
            { nixpkgs.overlays = [ nix-home.overlays.default ]; }

            home-manager.darwinModules.home-manager
            {
              home-manager = hmDefaults // {
                # nix-ai modules get their inputs via _module.args (self-contained);
                # nix-home modules accept userConfig with sensible defaults.
                # `hostConfig` threads the per-host attrset to home-manager modules.
                extraSpecialArgs = {
                  inherit
                    dotgithub
                    hostConfig
                    nix-ai
                    nix-openwhispr
                    ;
                  # Host-stamped: see hostUserConfig above.
                  userConfig = hostUserConfig;
                };
                users.${userConfig.user.name} = import ./hosts/${label}/home.nix;

                # Shared modules from external flakes:
                # - nix-ai: Claude, Gemini, Copilot, MCP servers, marketplace plugins
                # - nix-home: git, zsh, vscode, direnv, monitoring, tmux, common packages
                #
                # GUI apps use home-manager copyApps (~/Applications/Home Manager Apps/,
                # stable paths for TCC persistence), so no app-trampoline module is needed.
                sharedModules = [
                  nix-ai.homeManagerModules.default
                  nix-home.homeManagerModules.default
                ]
                ++ lib.optionals (label == "macbook-m4") [
                  nix-ai-open-harness.homeManagerModules.default
                  nix-openwhispr.homeManagerModules.default
                ];
              };
            }
          ];
        };

      # Map every registry entry to darwinConfigurations.<hostName>.
      configs = lib.mapAttrs' (label: host: lib.nameValuePair host.hostName (mkHost label host)) hosts;

      # Resolve the primary host dynamically (the one with `primary = true`) so
      # flake.nix stays decoupled from specific host labels.
      primaryHost = lib.head (lib.filter (h: h.primary or false) (lib.attrValues hosts));
    in
    {
      # One entry per host, keyed by hostName so `darwin-rebuild switch --flake .`
      # host auto-detection resolves it, plus a `default` alias to the primary machine.
      darwinConfigurations = configs // {
        default = configs.${primaryHost.hostName};
      };

      # CI-friendly outputs for GitHub Actions validation
      # Claude settings JSON now computed by nix-ai (self-contained)
      # hmActivationPackage still requires Darwin (kept for macOS CI)
      lib = {
        ci = {
          inherit (nix-ai.lib.ci) claudeSettingsJson;
          hmActivationPackage =
            configs.${primaryHost.hostName}.config.home-manager.users.${userConfig.user.name}.home.activationPackage;
        };
      };

      # Expose custom packages for nix-update automation
      packages.aarch64-darwin = {
        cribl-edge = nixpkgs.legacyPackages.aarch64-darwin.callPackage ./packages/cribl-edge.nix { };
      };

      # Formatter for `nix fmt` command
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;

      # Quality checks for `nix flake check` (DRY principle).
      # Scoped to x86_64-linux: source-only checks run once on CI runner.
      checks =
        let
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          ${system} = import ./lib/checks.nix {
            inherit pkgs;
            src = ./.;
            darwinConfigurations = { };
          };
        };

      # Development shell for CI and local nix tooling
      devShells.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
        packages = with nixpkgs.legacyPackages.aarch64-darwin; [
          nixfmt
          statix
          deadnix
          treefmt
          yq-go
        ];
      };
    };
}
