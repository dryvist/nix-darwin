# User-Specific Configuration Variables
#
# Centralizes user-specific values that may vary between machines or users.
# Import this file wherever user-specific values are needed.
#
# These values are safe to commit to git:
# - GPG key IDs are public identifiers (not private keys)
# - Email addresses are often public (GitHub noreply recommended)
# - Usernames are public information

let
  # Define username once, derive everything else from it
  username = "jevans";

  # Home directory path (derived from username for macOS)
  # macOS-specific - this configuration is Darwin-only
  # Use this for paths in darwin modules where config.home.homeDirectory
  # is not available
  homeDir = "/Users/${username}";
in
{
  # ==========================================================================
  # User Identity
  # ==========================================================================
  user = {
    # System username (matches macOS account)
    name = username;

    # Expose homeDir for modules that need it
    inherit homeDir;

    # Full name for git commits and other identity purposes
    fullName = "JacobPEvans-personal";

    # Primary email (GitHub noreply for privacy)
    # Account renamed JacobPEvans -> JacobPEvans-personal; the noreply email and
    # signing key below must match the renamed account or commits fail signature
    # verification (bad_email). fullName is display-only and does not affect it.
    email = "20714140+JacobPEvans-personal@users.noreply.github.com";
  };

  # ==========================================================================
  # Host Configuration
  # ==========================================================================
  host = {
    # Network hostname (used for networking.hostName, ComputerName, etc.)
    name = "jevans-mbp";
  };

  # ==========================================================================
  # GPG Configuration
  # ==========================================================================
  # NOTE: These are PUBLIC key identifiers, NOT private keys.
  # Safe to commit - GitHub displays these on every signed commit.
  gpg = {
    # Primary signing key ID (public identifier) for the JacobPEvans-personal account
    signingKey = "1335F5D082489BBA";
  };

  # ==========================================================================
  # Git Configuration
  # ==========================================================================
  git = {
    # Default editor for commit messages
    editor = "vim";

    # Default branch name for new repositories
    defaultBranch = "main";
  };

  # ==========================================================================
  # AI Assistant Configuration
  # ==========================================================================
  # ai-assistant-instructions content comes from the Nix store (flake input);
  # no local-repo path is needed for runtime use.
  ai = {
    # Claude Code settings JSON Schema URL (official schema store)
    # Used by: settings.json $schema, pre-commit hooks, CI validation, activation hooks
    # Single source of truth - reference this everywhere
    claudeSchemaUrl = "https://json.schemastore.org/claude-code-settings.json";
  };

  # ==========================================================================
  # Logging Configuration
  # ==========================================================================
  logging = {
    syslog = {
      # Remote syslog server for centralized log collection
      # Logs are forwarded via macOS built-in syslogd to HAProxy -> Cribl Edge -> Splunk
      server = "haproxy.jacobpevans.com";
      port = 1514;
      # Protocol: udp or tcp
      protocol = "udp";
    };
  };

  # ==========================================================================
  # macOS Keychain Configuration
  # ==========================================================================
  keychain = {
    # Account name for AI/automation secrets (stored separately from personal credentials)
    # Secrets are stored in aiDb, not the login keychain, to keep them isolated.
    # Add secrets with: security add-generic-password -U -s <service> -a <aiAccount> -w "<value>" <aiDb>
    aiAccount = "ai-cli-coder";

    # Dedicated keychain database for AI/automation secrets
    aiDb = "automation.keychain-db";
  };

  # ==========================================================================
  # GitHub Token Configuration
  # ==========================================================================
  github = {
    tokens = {
      # Tiered GitHub PATs — each tier specifies its keychain service + DB.
      # Auto-readable automation keychain (no password prompt; AI can access freely):
      #   restricted → public repos
      #   dryvist    → dryvist org repos (public + private) — the DEFAULT tier
      # Password-protected keychain (requires interactive user unlock):
      #   private    → JacobPEvans-personal public + private repos
      #   admin      → JacobPEvans-personal admin (rulesets, branch protection)
      #   orgAdmin   → dryvist org admin (org-level rulesets)
      #
      # NOTE: dryvist lives in the auto-readable keychain by deliberate choice —
      # it is the default tier (see home.nix), so it must load without a password
      # prompt on every shell. This means the dryvist token (write access to all
      # dryvist repos) is freely readable by the user session and AI agents. This
      # trades the former least-privilege RESTRICTED default for zero keychain
      # popups, per an explicit decision on 2026-05-28.
      restricted = {
        service = "GH_PAT_RESTRICTED";
        keychain = "automation.keychain-db";
      };
      dryvist = {
        service = "GH_PAT_DRYVIST";
        keychain = "automation.keychain-db";
      };
      private = {
        service = "GH_PAT_PRIVATE";
        keychain = "elevate-access.keychain-db";
      };
      admin = {
        service = "GH_PAT_ADMIN";
        keychain = "elevate-access.keychain-db";
      };
      orgAdmin = {
        service = "GH_PAT_ORG_ADMIN";
        keychain = "elevate-access.keychain-db";
      };
    };
  };

  # ==========================================================================
  # Nix/NixOS Configuration
  # ==========================================================================
  nix = {
    # Home-manager stateVersion - single source of truth
    # NixOS 25.11 "Vicuna" (released November 2025)
    # Update this when upgrading to a new NixOS stable release
    # Reference: https://nixos.org/blog/announcements/
    homeManagerStateVersion = "25.11";
  };
}
