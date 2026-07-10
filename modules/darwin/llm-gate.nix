# llm-large L7 Gate (launchd Caddy, secrets pulled live from Doppler)
#
# ADR (docs-starlight d/decisions/llm-large-studio-serving.mdx): the model
# server stays bound to 127.0.0.1; this Caddy front terminates TLS on the
# host's LAN address and enforces a bearer token (the OpenAI `api_key` field,
# native in every consumer). It is the only network path to the model port.
# API-only: the chat UI moved to the single cluster-hosted Open WebUI, so this
# gate no longer fronts a local web UI. `extraHostnames` lets the one API site
# also answer for service aliases (e.g. an `llm-large.<subdomain>` CNAME) so
# the cert/SNI covers them alongside the host FQDN.
#
# Secrets are NOT stored on this host. Nothing sensitive is baked into the
# Caddyfile, the plist, or sops — not the bearer token, not the Route53 ACME
# credentials, not even the AWS region (infra topology is treated as sensitive
# in a public repo). Doppler is the single source of truth. The launchd agent
# wraps Caddy in `doppler run`, which injects the secrets as environment
# variables live at each (re)start; the Caddyfile references them purely as
# `{env.VAR}` placeholders that Caddy resolves at parse time. Rotate a value in
# Doppler and restart the agent — nothing local ever holds a copy, so there is
# no sops<->Doppler drift. (OpenBao with fine-grained policies is the eventual
# target, JAC-153; Doppler is the current stopgap that already backs the fleet.)
#
# User agent, not root daemon: the gated port is non-privileged and Doppler
# auth lives in the login user's ~/.doppler (a headless root daemon has no
# Doppler session — the same reason activation scripts must never call Doppler).
# The server host auto-logs-in, so the agent comes up unattended on boot. The
# one local bootstrap credential is a read-only, config-scoped Doppler service
# token provisioned once into ~/.doppler, scoped to this agent's WorkingDirectory
# — a pointer to Doppler, never a copy of the secrets it fetches.
#
# TLS modes:
#   route53  — real Let's Encrypt cert via DNS-01 against the public zone,
#              using the same least-privilege `acme` AWS user the cluster
#              ingress already uses (credentials injected from Doppler).
#   internal — Caddy's local CA (autonomous, no external dependency); clients
#              must trust the CA or skip verification. Bring-up stopgap only.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.llm-gate;
  userConfig = import ../../lib/user-config.nix;

  # caddy-dns/route53 pinned with the FOD hash for this caddy 2.11.4 +
  # plugin v1.6.2 pair; bump both together when either moves.
  caddyPkg =
    if cfg.tlsMode == "route53" then
      pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/route53@v1.6.2" ];
        hash = "sha256-dxrfc6o6PBxRqMRUDpenHDctHUNQx4ZmAy9577RTTKg=";
      }
    else
      pkgs.caddy;

  # Route53 credentials + region come from Doppler-injected env at runtime; the
  # Caddyfile only names them. `internal` mode needs no credentials at all.
  tlsDirective =
    if cfg.tlsMode == "route53" then
      ''
        tls {
              dns route53 {
                access_key_id {env.AWS_ACME_ACCESS_KEY_ID}
                secret_access_key {env.AWS_ACME_SECRET_ACCESS_KEY}
                region {env.LLM_GATE_AWS_REGION}
              }
            }''
    else
      "tls internal";

  # The API site answers for the host FQDN plus any service-alias hostnames.
  # Caddy takes a space-separated address list for a single site and obtains
  # one certificate covering every listed hostname. lib.unique guards against a
  # duplicate site address (and duplicate cert request) if a consumer lists
  # `domain` again in `extraHostnames`.
  apiSiteAddresses = lib.concatMapStringsSep " " (host: "https://${host}:${toString cfg.apiPort}") (
    lib.unique ([ cfg.domain ] ++ cfg.extraHostnames)
  );

  # Optional second gated site for the night-cluster endpoint (same bearer
  # token, same cert, own port + access log). Rendered only when a night
  # upstream is configured.
  nightSite = lib.optionalString (cfg.nightUpstreamPort != null) ''
    ${
      lib.concatMapStringsSep " " (host: "https://${host}:${toString cfg.nightPort}") (
        lib.unique ([ cfg.domain ] ++ cfg.extraHostnames)
      )
    } {
      ${tlsDirective}
      log {
        output file ${cfg.logDir}/night-access.json
        format json
      }
      @unauthorized not header Authorization "Bearer {env.LLM_LARGE_BEARER_TOKEN}"
      respond @unauthorized 401
      reverse_proxy 127.0.0.1:${toString cfg.nightUpstreamPort}
    }
  '';

  # The whole Caddyfile is a plain, secret-free nix store file: every sensitive
  # value is an {env.VAR} placeholder resolved by Caddy at parse time from the
  # Doppler-injected environment. Safe to be world-readable — it contains no
  # secrets, only the (already public) hostnames.
  caddyfile = pkgs.writeText "llm-gate.Caddyfile" ''
    {
      admin off
      auto_https disable_redirects
    }

    ${apiSiteAddresses} {
      ${tlsDirective}
      # JSON access log — the only place API-consumer traffic is visible (the
      # model server on loopback only ever sees the proxy). Written into the
      # gate's log dir (0755, outside the 0700 dataDir so a non-root Cribl
      # Edge can traverse it; ~/Library/Logs per macOS convention) and tailed
      # by the Cribl Edge in_gate_access file input (hosts/common). Caddy's
      # default rolling applies (100 MiB rolls, keep 10, 90 days), so no
      # newsyslog entry is needed.
      log {
        output file ${cfg.logDir}/access.json
        format json
      }
      @unauthorized not header Authorization "Bearer {env.LLM_LARGE_BEARER_TOKEN}"
      respond @unauthorized 401
      reverse_proxy 127.0.0.1:${toString cfg.apiUpstreamPort}
    }

    ${nightSite}
  '';
in
{
  options.programs.llm-gate = {
    enable = lib.mkEnableOption "TLS + bearer-token gate (Caddy) in front of the local LLM stack";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "host.example.com";
      description = "Public FQDN the gate serves (certificate subject).";
    };

    extraHostnames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "llm-large.example.com" ];
      description = ''
        Additional hostnames the API site also answers for (e.g. a service-alias
        CNAME pointing at this host). Each is added to the Caddy site address
        list so the obtained certificate covers it and SNI succeeds — without
        this, an alias hitting the gate fails TLS because the cert only covers
        `domain`. In route53 mode the DNS-01 challenge is solved for every site
        hostname automatically, so no per-name tls entry is needed.
      '';
    };

    tlsMode = lib.mkOption {
      type = lib.types.enum [
        "route53"
        "internal"
      ];
      default = "route53";
      description = "Certificate source: Let's Encrypt DNS-01 via Route53 (ACME AWS credentials injected from Doppler) or Caddy's internal CA (autonomous stopgap).";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Gated OpenAI-compatible API port on the LAN bind address (mirrors the loopback llama-swap port so consumers keep the :11434 convention).";
    };

    apiUpstreamPort = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Loopback llama-swap port the API site proxies to.";
    };

    nightPort = lib.mkOption {
      type = lib.types.port;
      default = 11440;
      description = "Gated night-cluster API port on the LAN bind address (mirrors the loopback night port, same convention as apiPort).";
    };

    nightUpstreamPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Loopback night-cluster (mlx-lm rank 0) port to gate; null renders no night site.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = userConfig.user.name;
      description = "Login user that owns the agent, the data dir, and the ~/.doppler service token (Doppler auth is per-user; the gate runs as a user LaunchAgent).";
    };

    dopplerProject = lib.mkOption {
      type = lib.types.str;
      default = "iac-conf-mgmt";
      description = "Doppler project supplying the gate's secrets (bearer token + Route53 ACME creds + region). The scoped service token in ~/.doppler already binds this project/config; kept here for documentation and a drift-free reference.";
    };

    dopplerConfig = lib.mkOption {
      type = lib.types.str;
      default = "prd";
      description = "Doppler config within the project (see dopplerProject).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/.local/share/llm-gate";
      description = "User-owned state dir (Caddy cert/config storage). Also the agent's WorkingDirectory, which the ~/.doppler service token is scoped to so `doppler run` resolves the right config non-interactively.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/Library/Logs/llm-gate";
      description = "Log directory (access log + launchd stdout/stderr), kept OUTSIDE the 0700 dataDir so a non-root Cribl Edge can read it; macOS user-log convention.";
    };
  };

  config = lib.mkIf cfg.enable {
    # User-owned state dir (install -d as root during activation, owned by the
    # login user so the agent — and `doppler run` — can read/write it).
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0700 "${cfg.dataDir}" "${cfg.dataDir}/data" "${cfg.dataDir}/config"
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0755 "${cfg.logDir}"
    '';

    # launchd USER agent: `doppler run` fetches the gate's secrets from Doppler
    # and injects them as env vars, then execs Caddy against the secret-free
    # Caddyfile. KeepAlive keeps it running and restarts it (picking up rotated
    # secrets on restart); no RunAtLoad/PathState dance is needed because there
    # is no sops-rendered file to wait for anymore. If the network or Doppler is
    # briefly unavailable at boot, Caddy exits and launchd retries on the
    # ThrottleInterval (Doppler's local fallback cache covers transient API
    # outages).
    launchd.user.agents.llm-gate.serviceConfig = {
      Label = "com.nix-darwin.llm-gate";
      ProgramArguments = [
        (lib.getExe pkgs.doppler)
        "run"
        "--project"
        cfg.dopplerProject
        "--config"
        cfg.dopplerConfig
        "--"
        (lib.getExe caddyPkg)
        "run"
        "--config"
        "${caddyfile}"
        "--adapter"
        "caddyfile"
      ];
      KeepAlive = true;
      ThrottleInterval = 15;
      WorkingDirectory = cfg.dataDir;
      EnvironmentVariables = {
        # HOME so `doppler` finds ~/.doppler (its scoped service token); Caddy's
        # own storage is pinned under the gate dir via XDG below.
        HOME = userConfig.user.homeDir;
        XDG_DATA_HOME = "${cfg.dataDir}/data";
        XDG_CONFIG_HOME = "${cfg.dataDir}/config";
      };
      StandardOutPath = "${cfg.logDir}/llm-gate.log";
      StandardErrorPath = "${cfg.logDir}/llm-gate.error.log";
    };
  };
}
