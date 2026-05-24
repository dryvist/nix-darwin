{
  # Nix-darwin flake configuration
  description = "nix-darwin configuration for M4 Max MacBook Pro";

  inputs = {
    # Using stable nixpkgs-25.11 for reliability
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    # Consolidated systems input for darwin-only configuration
    # All transitive dependencies should follow this to avoid duplicate systems entries
    systems.url = "github:nix-systems/default-darwin";

    # Using stable nix-darwin-25.11 to match nixpkgs
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Using stable home-manager release-25.11 to match nixpkgs
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # mac-app-util: Create app trampolines for /Applications/Nix Apps/ (system-level)
    # Used ONLY at darwin level for environment.systemPackages apps.
    # Home-manager apps use copyApps instead (see hosts/macbook-m4/home.nix).
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      # Consolidate all input overrides in a single attrset
      # - nixpkgs: use our root nixpkgs
      # - systems: use our consolidated darwin-only systems
      # - treefmt-nix: transitive dependency, prevent duplicate nixpkgs in flake.lock
      # - cl-nix-lite: WORKAROUND for gitlab.common-lisp.net Anubis anti-bot protection
      #   See: https://github.com/hraban/mac-app-util/issues/39
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
        cl-nix-lite.url = "github:r4v3n6101/cl-nix-lite/url-fix";
      };
    };

    # Direct inputs for independent updating (follows into nix-ai)
    # These are non-flake repos — zero transitive deps, always a 6-line flake.lock diff
    jacobpevans-cc-plugins = {
      url = "github:JacobPEvans/claude-code-plugins";
      flake = false;
    };
    ai-assistant-instructions = {
      url = "github:JacobPEvans/ai-assistant-instructions";
      flake = false;
    };
    claude-code-plugins = {
      url = "github:anthropics/claude-code";
      flake = false;
    };
    pal-mcp-server = {
      url = "github:BeehiveInnovations/pal-mcp-server";
      flake = false;
    };

    # AI CLI ecosystem (Claude, Gemini, Copilot, MCP, marketplace)
    # Self-contained: injects its own flake inputs via _module.args
    nix-ai = {
      url = "github:JacobPEvans/nix-ai";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        # Independent update paths — no need to update nix-ai for these
        jacobpevans-cc-plugins.follows = "jacobpevans-cc-plugins";
        ai-assistant-instructions.follows = "ai-assistant-instructions";
        claude-code-plugins.follows = "claude-code-plugins";
        pal-mcp-server.follows = "pal-mcp-server";
      };
    };

    # Cross-platform home-manager modules (git, zsh, vscode, monitoring, shells)
    nix-home = {
      url = "github:JacobPEvans/nix-home";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Official Determinate Nix module for nix-darwin
    # Manages nix.conf, determinate-nixd config, and GC automatically
    # Updates tracked by deps-update-flake.yml (daily nix flake update) + Renovate
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    # sops-nix: declarative secret management — decrypts age-encrypted secrets
    # to root-only files in /run/secrets at activation time
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      nixpkgs,
      darwin,
      home-manager,
      mac-app-util,
      nix-ai,
      nix-home,
      determinate,
      sops-nix,
      ...
    }:
    let
      userConfig = import ./lib/user-config.nix;
      hmDefaults = import ./lib/home-manager-defaults.nix;

      # Pass external sources to home-manager modules
      # nix-ai modules get their inputs via _module.args (self-contained)
      # nix-home modules accept userConfig with sensible defaults
      extraSpecialArgs = {
        inherit userConfig;
      };

      # Guard: fail at eval time if stateVersion drifts from nixpkgs branch.
      # When Renovate bumps nixpkgs-25.11 → nixpkgs-26.05, this assertion fires
      # with a clear message — the fix is to update lib/user-config.nix.
      _stateVersionCheck =
        let
          expected = "25.11"; # must match nixpkgs URL: nixpkgs-25.11-darwin
          actual = userConfig.nix.homeManagerStateVersion;
        in
        assert
          expected == actual
          || builtins.throw ''
            homeManagerStateVersion mismatch: expected "${expected}" (from nixpkgs branch) but got "${actual}".
            Update lib/user-config.nix when bumping nixpkgs.
          '';
        true;

      # Define configuration once, assign to multiple names
      darwinConfig =
        assert _stateVersionCheck;
        darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          # Pass nix-ai through so the homebrew module can pull
          # `lib.brewFormulae` (formulae required by per-agent home-manager
          # modules whose preferred install path is brew, e.g. qwen-code).
          # Keeps the agent module self-contained for future flake graduation —
          # see nix-ai/docs/architecture/per-agent-flakes.md.
          specialArgs = { inherit nix-ai; };
          modules = [
            ./hosts/macbook-m4/default.nix

            # Determinate Nix: official module for nix.conf, GC, and determinate-nixd config
            determinate.darwinModules.default

            # sops-nix: decrypts age-encrypted secrets to /run/secrets at activation
            sops-nix.darwinModules.sops

            # mac-app-util: Creates trampolines for system-level apps (/Applications/Nix Apps/)
            mac-app-util.darwinModules.default

            # Python package overlay from nix-home (replaces local overlays/python-packages.nix)
            { nixpkgs.overlays = [ nix-home.overlays.default ]; }

            home-manager.darwinModules.home-manager
            {
              home-manager = hmDefaults // {
                inherit extraSpecialArgs;
                users.${userConfig.user.name} = import ./hosts/macbook-m4/home.nix;

                # Shared modules from external flakes:
                # - nix-ai: Claude, Gemini, Copilot, MCP servers, marketplace plugins
                # - nix-home: git, zsh, vscode, direnv, monitoring, tmux, common packages
                #
                # NOTE: mac-app-util home-manager module REMOVED - using copyApps instead.
                # copyApps copies apps to ~/Applications/Home Manager Apps/ with stable paths,
                # making mac-app-util trampolines redundant for TCC permission persistence.
                # The darwin-level mac-app-util module is still used for /Applications/Nix Apps/.
                sharedModules = [
                  nix-ai.homeManagerModules.default
                  nix-home.homeManagerModules.default
                ];
              };
            }
          ];
        };
    in
    {
      # Both names point to same config:
      # - "default" for explicit #default usage
      # - hostname for auto-detection when # is omitted
      darwinConfigurations = {
        default = darwinConfig;
        ${userConfig.host.name} = darwinConfig;
      };

      # CI-friendly outputs for GitHub Actions validation
      # Claude settings JSON now computed by nix-ai (self-contained)
      # hmActivationPackage still requires Darwin (kept for macOS CI)
      lib = {
        ci = {
          inherit (nix-ai.lib.ci) claudeSettingsJson;
          hmActivationPackage =
            darwinConfig.config.home-manager.users.${userConfig.user.name}.home.activationPackage;
        };
      };

      # Expose custom packages for nix-update automation
      packages.aarch64-darwin = {
        claudebar = nixpkgs.legacyPackages.aarch64-darwin.callPackage ./packages/claudebar.nix { };
        cribl-edge = nixpkgs.legacyPackages.aarch64-darwin.callPackage ./packages/cribl-edge.nix { };
      };

      # Formatter for `nix fmt` command
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;

      # Quality checks for `nix flake check` (DRY principle).
      #
      # Scoped to x86_64-linux only so `nix flake check --all-systems` succeeds
      # from a single linux runner. All checks in lib/checks.nix are source-only
      # (formatting, statix, deadnix, shellcheck, shell-tests) — they operate
      # on the same source files regardless of target system, so running once
      # on the CI system is sufficient and equivalent. Other systems
      # intentionally have no `checks` entries.
      #
      # Cross-platform breakage (e.g. darwin-only `meta.broken` in nixpkgs) is
      # still caught by `--all-systems` evaluating `packages.aarch64-darwin`,
      # `devShells.aarch64-darwin`, `formatter.aarch64-darwin`, and the
      # `darwinConfigurations.*.system` derivations during flake evaluation.
      #
      # The darwin module-eval (only populated when `darwinConfigurations` is
      # non-empty) was previously gated on `system == aarch64-darwin`; combined
      # with the prior `all_systems: false` workaround, it never actually ran
      # in CI. Dropping it here is therefore no regression. If on-runner darwin
      # module-eval coverage is desired, run it as a post-merge job on a darwin
      # runner or via a dedicated workflow.
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
          nixfmt-rfc-style
          statix
          deadnix
          treefmt
          yq-go
        ];
      };
    };
}
