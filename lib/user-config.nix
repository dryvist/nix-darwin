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

  # GitHub handle, reused by the nix-ai agent profile below.
  fullName = "JacobPEvans";

  # Public DNS apex every homelab FQDN lives under. Defined ONCE — all other
  # names compose from it (docs host, syslog/LB target, per-host serving
  # domains via "${hostConfig.hostName}.${userConfig.baseDomain}"). Never
  # hard-code the domain at a use site.
  baseDomain = "jacobpevans.com";

  # Internal-services zone under the apex. Every homelab service that is not
  # published on the public apex resolves here — compose those FQDNs from this
  # var, never by re-spelling the zone label at a use site. Defined ONCE for
  # the same reason baseDomain is: a use site that omits it composes a name
  # that does not resolve, and the failure looks like an outage rather than a
  # typo (that is exactly how the open-harness endpoint came to point at a
  # nonexistent host).
  internalDomain = "pve.${baseDomain}";

  docsHost = "docs.${baseDomain}";
in
{
  # Public DNS apex (see let-binding above). Compose FQDNs from this.
  inherit baseDomain;

  # Internal-services zone (see let-binding above). Compose internal FQDNs
  # from this rather than re-spelling the zone at each use site.
  inherit internalDomain;

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
      # Homelab HAProxy LB — the Cribl Edge tcpjson target (hosts/common/
      # cribl.nix). The old syslogd remote forward that also used this block
      # is retired (see modules/darwin/logging.nix header); only the server
      # name remains in use.
      server = "haproxy.${internalDomain}";
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

  # GitHub token configuration intentionally removed: tokens are now minted on
  # demand by OpenBao (ephemeral GitHub App installation tokens) via the
  # openbao-github-creds git credential helper. The former tiered-PAT keychain
  # services (GH_PAT_RESTRICTED / DRYVIST / PRIVATE / ADMIN / ORG_ADMIN) are
  # retired — see the openbao-github-creds wrapper in modules/darwin.

  # ==========================================================================
  # Nix/NixOS Configuration
  # ==========================================================================
  nix = {
    # Home-manager stateVersion - single source of truth
    # NixOS 26.05 (released May 2026)
    # Kept in lockstep with the nixpkgs branch in flake.nix — the
    # _stateVersionCheck assertion there fails eval if the two drift.
    # Reference: https://nixos.org/blog/announcements/
    homeManagerStateVersion = "26.05";
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
      "Secrets stores: Doppler provides AI/MCP keys through locally selected project/configuration; macOS Keychain (ai-secrets keychain holds ANTHROPIC_API_KEY etc.; elevate-access keychain holds the break-glass OPENBAO_TOKEN); OpenBao mints GitHub tokens on demand (ephemeral GitHub App installation tokens via the openbao-github-creds credential helper — the old GH_PAT keychain tiers are retired) and short-lived AWS STS creds; Mozilla SOPS handles at-rest encryption; Bitwarden vault plus Bitwarden Secrets Manager. No long-lived AWS keys — OIDC handles CI."
      "AI runtimes: local MLX server on this Mac (mlx-server devenv shell); Claude / Codex / Gemini / Copilot CLIs all routed through local dev shells; HuggingFace CLI handles model management."
      "Observability stack: OpenTelemetry instrumentation → Cribl Stream → Splunk Enterprise (homelab). splunk-dev devenv shell on local Splunk work."
      "Self-hosted runners: GitHub Actions self-hosted RunsOn runners labeled per the ${fullName}/.github v3 catalog. Jobs targeting RunsOn labels are routine."
      "Container deployment: LXC on Proxmox is the default in production homelab workloads. Docker only on vendor-locked images that require it (high-throughput network traffic must never flow through Docker's virtualized networking)."
      "Nix-first: nix-darwin (macOS), nix-home (cross-platform user env), nix-ai (AI tooling), nix-devenv (reusable dev shells plus flakeModules.dev-hygiene), nix-claude-code (Claude Code declarative module). Flakes-only — never use nix-env."
      "Pre-commit, linting, format: pre-commit hooks come from nix-devenv.flakeModules.dev-hygiene in Nix repos. zizmor policy from dryvist/.github (trusted publishers: actions/*, DeterminateSystems/*, googleapis/* may use ref-pins; everything else requires hash-pins)."
    ];

    # Auto-permit rules for actions whose real access control lives outside the
    # classifier, so it does not re-litigate a boundary something else enforces.
    allowRules = [
      "OpenTofu / Terraform in the homelab IaC repos — `tofu`/`terraform` init, plan, apply (including `-auto-approve`), refresh, import, and state list/show/rm/mv, including when wrapped in `doppler run`, `sops exec-env`, and `nix develop … --command bash -c '…'` — is operator-authorized infrastructure work. State backend and provider auth already gate what a run can touch; allow without confirmation."
      "OpenBao (BAO_ADDR/VAULT_ADDR) API interactions at every privilege tier — AppRole login, KV read and write, and admin/`sys` operations, via `curl`, the `bao`/`vault` CLI, or inside `doppler run` wrappers — are allowed without confirmation. OpenBao's own AppRole policies enforce access separation and reject unauthorized requests; the auto-mode classifier is not the guard here."
    ];
  };

  # Claude Code OpenTelemetry. Endpoints compose from internalDomain, never
  # re-spelled — see the let-binding above.
  #
  # Traces only. The collector behind that name extracts spans and forwards
  # them on; it does not extract metrics or logs, so pointing those signals at
  # it would hand over data the pipeline discards. nix-ai gates each signal on
  # its own endpoint and pins the unused exporters to `none`, so leaving
  # otlpEndpoint unset means metrics and logs are not emitted at all rather
  # than emitted to a conventional default address.
  #
  # Spans are also the signal worth having: session transcripts already carry
  # per-message token counts, while latency, tool duration, and subagent
  # structure exist nowhere else.
  telemetry = {
    enable = true;

    # Signal-specific, so it carries the full path — nothing is appended.
    # Setting it is also what turns span emission on at all.
    tracesEndpoint = "https://otel.${internalDomain}/v1/traces";

    serviceName = "claude-code";
    # host.name is per-host, so flake.nix's mkHost merges it in — this file is
    # host-agnostic and every host would otherwise report the same identity.

    # Ships full prompt and tool content. Deliberate, and only sound because
    # the collector and every hop past it are self-hosted on the internal zone.
    logUserPrompts = true;
    logToolDetails = true;
  };

  # Personal directories Claude Code may read without per-prompt approval.
  extraTrustedPaths = [ "~/.claude/skills/retrospecting/reports/" ];

  # Workspace roots whose CLAUDE.md external imports are auto-approved.
  trustedProjectDirs = [ "~/git/public/" ];
}
