{
  pkgs,
  hostConfig,
  ...
}:

let
  userConfig = import ../../lib/user-config.nix;
  # Server-class hosts get no GUI packages — lean by construction.
  # (isServer is normalized once in flake.nix mkHost.)
  inherit (hostConfig) isServer;
in
{
  imports = [
    ./sops.nix
    ./apps
    ./dock
  ]
  ++ (if builtins.pathExists ./local.nix then [ ./local.nix ] else [ ])
  ++ [
    ./energy.nix
    ./file-extensions.nix
    ./cluster-link-prep.nix
    ./cluster-rebuild-gate.nix
    ./cluster-maintenance-window.nix
    ./finder.nix
    ./homebrew.nix
    ./nix-homebrew.nix
    ./keyboard.nix
    ./launchd-bootstrap.nix
    ./launchd-self-heal.nix # Reload penalty-boxed critical KeepAlive daemons
    ./logging.nix # Syslog forwarding to remote server
    ./boot-activation.nix # Creates /run/current-system at boot
    ./auto-recovery.nix
    ./security.nix
    ./ssh-hardening.nix
    ./pf-hardening.nix
    ./trackpad.nix
    ./system-ui.nix
    ./activation-error-tracking.nix
    ./hm-activation-assert.nix # Fail the rebuild when home-manager did not apply
    ./llm-gate.nix
    ./nix-storage.nix
    ./ws-monitor.nix
    ./apple-silicon-tunables.nix
    ./system-limits.nix
    ./network-tuning.nix
  ];

  # --- Nixpkgs Configuration ---
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (import ../../overlays/direnv-darwin-fix.nix) # TEMPORARY: NixOS/nix#6065
    (import ../../overlays/python-darwin-test-fixes.nix) # TEMPORARY: pgvector + accelerate
  ];

  # --- User Configuration ---
  users.users.${userConfig.user.name} = {
    inherit (userConfig.user) name;
    home = userConfig.user.homeDir;
  };

  # System packages from nixpkgs
  # All packages should come from nixpkgs - homebrew is fallback only
  # NOTE: User dev tools (bat, ripgrep, jq, etc.) provided by nix-home via home.packages
  environment.systemPackages = with pkgs; [
    # ========================================================================
    # Core CLI tools (bootstrapping - needed before home-manager)
    # ========================================================================
    entire # AI-session capture for git (records live agent sessions)
    git
    gnupg
    vim

    # ========================================================================
    # Secret store client
    # ========================================================================
    # General client for the secret store: AppRole login, KV reads, and SSH
    # certificate signing (`bao ssh`, `bao write <mount>/sign/<role>`). The
    # openbao-*-creds wrappers in modules/darwin/apps wrap three specific
    # credential types; anything they do not wrap previously had no tool at
    # all, which pushed operators into hand-rolled curl against the HTTP API.
    openbao

    # ========================================================================
    # macOS-specific system tools
    # ========================================================================
    mas # Mac App Store CLI

    # ========================================================================
    # Network & process tools
    # ========================================================================
    ngrep # Network packet grep (useful for debugging)

    # ========================================================================
    # Audio libraries (system-level dependencies)
    # ========================================================================
    sox # Audio recording, conversion, and effects (Sound eXchange)
    portaudio # Cross-platform audio I/O library
  ];
  # GUI apps: SwiftBar via home-manager copyApps (hosts/macbook-m4/home.nix);
  # Raycast / Bitwarden / Ghostty / etc. are Homebrew casks (see homebrew.nix).

  # --- Homebrew Configuration ---
  # See ./homebrew.nix for casks, brews, and masApps

  # --- Programs Configuration ---
  programs = {
    zsh.enable = true;
    raycast.enable = !isServer;
  };

  documentation.enable = false;

  # --- System Configuration (Activation Scripts) ---
  # Activation scripts verify system state and prevent silent failures
  # ⚠️ CRITICAL: See docs/ACTIVATION-SCRIPTS-RULES.md for mandatory rules
  system = {
    # Required for nix-darwin with Determinate Nix
    primaryUser = userConfig.user.name;

    activationScripts = {
      preActivation.text = ''
        # CRITICAL: Disable 'set -e' to prevent non-zero exit codes from aborting
        # the entire activation script. See docs/ACTIVATION-SCRIPTS-RULES.md Rule 1.
        #
        # Summary: nix-darwin's activate script uses 'set -e'. Commands like
        # 'launchctl asuser' return non-zero exit codes even on success. Without
        # 'set +e', the script aborts BEFORE updating /run/current-system, causing
        # a silent partial deployment (home-manager updates but system stays old).
        set +e

        echo "→ Starting activation (user: $(whoami), uid: $(id -u))"

        # Trap signals to prevent leaving system in bad state if interrupted
        cleanup() {
          echo "❌ Activation interrupted - system may be in an inconsistent state" >&2
          echo "Run: sudo darwin-rebuild activate" >&2
          exit 1
        }
        trap cleanup INT TERM

        # NOTE: do NOT pre-check /run here. On a fresh Mac /run does not exist
        # until upstream nix-darwin's own createRun activation step provisions
        # it (synthetic.conf + apfs.util, modules/system/base.nix) — a check
        # this early aborts first bootstrap on brand-new machines (hit on
        # jevans-ms 2026-07-02). Upstream already fails loudly if /run cannot
        # be created, so a duplicate guard adds risk and no protection.
      '';

      # Runs after all activation scripts, just before symlink update
      # NOTE: Can't verify /run/current-system here - it updates after this script
      postActivation.text = ''
        # Format the system-config mtime (macOS format: Mon DD HH:MM:SS YYYY)
        TIMESTAMPS=$(stat -f '%Sm' -t '%b %e %H:%M:%S %Y' "$systemConfig" 2>/dev/null)

        echo "✅ Activation complete → $systemConfig"
        echo "   Timestamp: $TIMESTAMPS"

        # ====================================================================
        # Post-Activation Comprehensive Diagnostics
        # ====================================================================
        # Verify that the activation actually succeeded and provide clear
        # diagnostics for debugging exit code issues (especially exit code 2
        # from launchctl asuser calls during home-manager activation)

        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Post-activation verification starting..."

        # Check if /run/current-system symlink was updated (proves activation succeeded)
        if [ -L /run/current-system ]; then
          CURRENT_SYSTEM=$(readlink /run/current-system)
          echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ✓ System activation succeeded"
          echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Current system: $CURRENT_SYSTEM"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] /run/current-system symlink not found" >&2
          echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Activation may have failed - check logs above" >&2
        fi

        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ============================================"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] darwin-rebuild completed"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ============================================"
      '';
    };

    # macOS system version (required for nix-darwin)
    stateVersion = 5;
  };
}
