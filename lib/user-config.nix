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

  # GitHub handle / public docs host, reused by the nix-ai agent profile below.
  fullName = "JacobPEvans";
  docsHost = "docs.jacobpevans.com";
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
    inherit fullName;

    # Primary email (GitHub noreply for privacy)
    # Account renamed JacobPEvans -> JacobPEvans-personal; the noreply email and
    # signing key below must match the renamed account or commits fail signature
    # verification (bad_email). fullName is display-only and does not affect it.
    email = "20714140+JacobPEvans-personal@users.noreply.github.com";

    # Additional GitHub org (besides fullName) trusted in Claude auto-mode.
    # Consumed by nix-ai's userConfig.user.trustedOrgs.
    trustedOrgs = [ "dryvist" ];
  };

  # ==========================================================================
  # Host Configuration
  # ==========================================================================
  host = {
    # Network hostname (used for networking.hostName, ComputerName, etc.)
    name = "jevans-mbp";

    # LAN DNS resolver(s) and search domain (match the host resolver). Used to
    # give containers the same name resolution as the host. Non-secret.
    lanDnsServers = [ "10.0.1.1" ];
    lanSearchDomain = "jacobpevans.com";
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
  # Logging Configuration
  # ==========================================================================
  logging = {
    syslog = {
      # Remote syslog server for centralized log collection
      # Logs are forwarded via macOS built-in syslogd to HAProxy -> Cribl Edge -> Splunk
      server = "haproxy.pve.jacobpevans.com";
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
  # AI Stack Configuration
  # ==========================================================================
  ai = {
    # Local MLX physical model id consumed at Nix eval time by
    # services.aiStack.defaultLocalModelId (hosts/macbook-m4/services-ai-stack.nix).
    # Non-secret — a public Hugging Face model name. Committed here like every
    # other eval-time identifier so evaluation stays pure (no --impure, no
    # keychain/env/file sourcing). Change the model via a reviewed commit.
    # 2026-06-09: switched from mlx-community/Qwen3.6-35B-A3B-mxfp4 — its hybrid
    # linear-attention architecture (qwen3_5_moe) crashes vllm-mlx whenever two
    # requests batch (mlx-lm conv_state shape bug; 402 crash-recovery events in
    # one log window, 0.1-4 tok/s effective). Qwen3-30B-A3B-Instruct-2507 is a
    # standard-attention MoE (qwen3_moe): benched 80-98 tok/s single-stream,
    # ~85 tok/s aggregate at 4-way concurrency, zero crashes, hermes tool
    # calling. See dryvist/nix-ai#915.
    defaultLocalModelId = "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit";
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

  # ==========================================================================
  # AI Agent Profile (nix-ai)
  # ==========================================================================
  # nix-ai ships neutral defaults; this is the consumer-side re-injection of
  # this machine's homelab context. Consumed by nix-ai's userConfig surface
  # (modules/maintainer-profile.nix) via extraSpecialArgs in flake.nix.

  # Trusted-infrastructure prose for Claude auto-mode, so routine cross-repo,
  # cloud, and homelab actions are not flagged as exfiltration.
  homelab = {
    enable = true;
    environmentRules = [
      "Single-developer personal homelab plus day-job (Splunk/Cribl architect). Public docs map: https://${docsHost} (source github.com/${fullName}/docs) covers Infrastructure, Nix ecosystem, AI development, Observability, Security, and Tools surfaces."
      "Workspace layout: each repo is a clone on its default branch. Create an isolated worktree for feature work via the AI tool's native mechanism (Claude's EnterWorktree, which lands worktrees under .claude/worktrees/). Never run `git worktree add` into a path inside the repo's working tree — that pollutes the main checkout; place any manual worktree as a sibling of the clone, never a child."
      "Cloud: AWS via aws-vault profiles (terraform-aws, terraform-aws-bedrock); Proxmox cluster on the home LAN (terraform-proxmox plus ansible-proxmox-*). No multi-tenant production."
      "Secrets stores: Doppler (ai-ci-automation/prd project carries AI/MCP keys); macOS Keychain (ai-secrets keychain holds ANTHROPIC_API_KEY etc.; elevate-access keychain holds elevated GH tokens via the RESTRICTED/PRIVATE/ADMIN tier system); Mozilla SOPS handles at-rest encryption; Bitwarden vault plus Bitwarden Secrets Manager. No long-lived AWS keys — OIDC handles CI."
      "AI runtimes: local MLX server on this Mac (mlx-server devenv shell); Claude / Codex / Gemini / Copilot CLIs all routed through local dev shells; HuggingFace CLI handles model management."
      "Observability stack: OpenTelemetry instrumentation → Cribl Stream → Splunk Enterprise (homelab). splunk-dev devenv shell on local Splunk work."
      "Self-hosted runners: GitHub Actions self-hosted RunsOn runners labeled per the ${fullName}/.github v3 catalog. Jobs targeting RunsOn labels are routine."
      "Container deployment: LXC on Proxmox is the default in production homelab workloads. Docker only on vendor-locked images that require it (high-throughput network traffic must never flow through Docker's virtualized networking)."
      "Nix-first: nix-darwin (macOS), nix-home (cross-platform user env), nix-ai (AI tooling), nix-devenv (reusable dev shells plus flakeModules.dev-hygiene), nix-claude-code (Claude Code declarative module). Flakes-only — never use nix-env."
      "Pre-commit, linting, format: pre-commit hooks come from nix-devenv.flakeModules.dev-hygiene in Nix repos. zizmor policy from dryvist/.github (trusted publishers: actions/*, DeterminateSystems/*, googleapis/* may use ref-pins; everything else requires hash-pins)."
    ];
  };

  # Claude Code OpenTelemetry → local OrbStack k8s OTEL collector. nix-ai
  # resolves the endpoint port from its registry (nodeports.otel_grpc).
  telemetry.enable = true;

  # Personal directories Claude Code may read without per-prompt approval.
  extraTrustedPaths = [ "~/.claude/skills/retrospecting/reports/" ];

  # Workspace roots whose CLAUDE.md external imports are auto-approved.
  trustedProjectDirs = [ "~/git/public/" ];
}
