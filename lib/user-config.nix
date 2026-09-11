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
  # Automation Identities
  # ==========================================================================
  # Dedicated macOS accounts that AI harnesses run under, one per trust tier,
  # so nothing an agent does runs as the operator. Consumed by
  # modules/darwin/agent-identity.nix (accounts, the `agent` group, sudoers)
  # and flake.nix (one home-manager home per identity).
  #
  # `converge` is the capability gate: only an identity with `converge = true`
  # gets the NOPASSWD `darwin-rebuild switch` rule, and only that identity is
  # listed in Nix `trusted-users` (modules/darwin/nix-storage.nix). Both are
  # root-equivalent — never default them on for a new identity. `checkout` is
  # the flake path relative to the identity's home, so the sudoers flake
  # reference composes as "${homeDir}/${checkout}" and no absolute path or
  # host name is ever committed; an identity without `converge` has no use for
  # it and omits it.
  #
  # uids climb from 505 (first free on these hosts). Every identity keeps
  # `staff` (gid 20) as its primary group — that is what lets it read the
  # operator's group-readable files — and additionally joins `agent`.
  agentUsers = {
    claude = {
      name = "claude";
      uid = 505;
      homeDir = "/Users/claude";
      checkout = "git/public/nix/nix-darwin";
      converge = true;
    };
    # Runs opencode and cursor CLI: executes model-generated code from a
    # lower-trust tool, so no converge grant and no trusted-user status.
    open-llm = {
      name = "open-llm";
      uid = 506;
      homeDir = "/Users/open-llm";
      converge = false;
    };
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
  # (modules/maintainer-profile.nix) via extraSpecialArgs in flake.nix. The
  # prose lives in its own file to keep this one under the file-size gate.
  homelab = import ./homelab-profile.nix { inherit fullName docsHost; };

  # Claude Code OpenTelemetry. Endpoints compose from internalDomain, never
  # re-spelled — see the let-binding above.
  #
  # Each signal goes to the service that actually stores it, and no signal is
  # aimed at one that does not. The span collector extracts spans only, so
  # metrics pointed at it would be discarded; the metrics store ingests OTLP
  # metrics and serves no logs route, so logs pointed at it would fail every
  # export interval. nix-ai gates each signal on its own endpoint and pins the
  # unused exporters to `none`, so an unset endpoint means that signal is not
  # emitted at all rather than emitted to a conventional default address.
  #
  # Logs ride the generic endpoint (a BASE url; the exporter appends
  # /v1/logs) and carry the per-request api_request event.
  telemetry = {
    enable = true;
    otlpEndpoint = "https://otel.${internalDomain}";

    # Signal-specific, so it carries the full path — nothing is appended.
    # Setting it is also what turns span emission on at all.
    tracesEndpoint = "https://otel.${internalDomain}/v1/traces";

    # Also signal-specific and full-path. The metrics store resolves at the
    # public apex rather than the internal zone, and is reached directly on its
    # own port — there is no ingress vhost in front of it. Its OTLP route is
    # under /opentelemetry, and it runs with Prometheus naming on, so the
    # counters land under the names the vendored dashboard queries.
    metricsEndpoint = "http://grafana.${baseDomain}:8428/opentelemetry/v1/metrics";

    serviceName = "claude-code";
    # host.name is per-host, so flake.nix's mkHost merges it in — this file is
    # host-agnostic and every host would otherwise report the same identity.

    # Full prompt and tool content is sensitive even on a self-hosted
    # collector (pasted secrets, credentials). Keep both off.
    logUserPrompts = false;
    logToolDetails = false;
  };

  # Personal directories Claude Code may read without per-prompt approval.
  extraTrustedPaths = [ "~/.claude/skills/retrospecting/reports/" ];

  # Workspace roots whose CLAUDE.md external imports are auto-approved.
  trustedProjectDirs = [ "~/git/public/" ];
}
