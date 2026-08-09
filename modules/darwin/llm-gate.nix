# llm-large L7 Gate (launchd Caddy, secrets pulled live from OpenBao).
#
# Design rationale — role, loopback bind, OpenBao secret-zero, TLS modes — lives
# in ./llm-gate.md (kept out of this file so it stays under the byte-size gate).

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
        hash = "sha256-/9c9b+S98V+eDj6mzb6KfAWWSBCrZoUzA1JDrMxuKQ0=";
      }
    else
      pkgs.caddy;

  # Route53 credentials + region come from openbao-run-injected env at runtime; the
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

  # Pin every listener to the host's LAN address(es) so Caddy never binds the
  # wildcard socket (INC-17114). Empty list keeps Caddy's default. See
  # ./llm-gate.md and the bindAddresses option.
  bindDirective = lib.optionalString (cfg.bindAddresses != [ ]) (
    "bind " + lib.concatStringsSep " " cfg.bindAddresses
  );

  # L6 input bound — ordered ahead of reverse_proxy, so an oversized body is
  # refused before anything downstream allocates KV. See ./llm-gate.md.
  requestBodyDirective = lib.optionalString (cfg.maxRequestBytes != null) ''
    request_body {
        max_size ${cfg.maxRequestBytes}
      }'';

  # Optional second gated site for the cluster-mode endpoint (same bearer
  # token, same cert, own port + access log). Rendered only when a cluster
  # upstream is configured.
  clusterSite = lib.optionalString (cfg.clusterUpstreamPort != null) ''
    ${
      lib.concatMapStringsSep " " (host: "https://${host}:${toString cfg.clusterPort}") (
        lib.unique ([ cfg.domain ] ++ cfg.extraHostnames)
      )
    } {
      ${bindDirective}
      ${tlsDirective}
      ${requestBodyDirective}
      log {
        output file ${cfg.logDir}/cluster-access.json
        format json
      }
      @unauthorized not header Authorization "Bearer {env.LLM_LARGE_BEARER_TOKEN}"
      respond @unauthorized 401
      reverse_proxy 127.0.0.1:${toString cfg.clusterUpstreamPort}
    }
  '';

  # The whole Caddyfile is a plain, secret-free nix store file: every sensitive
  # value is an {env.VAR} placeholder resolved by Caddy at parse time from the
  # openbao-run-injected environment. Safe to be world-readable — it contains no
  # secrets, only the (already public) hostnames.
  caddyfile = pkgs.writeText "llm-gate.Caddyfile" ''
    {
      admin off
      auto_https disable_redirects
    }

    ${apiSiteAddresses} {
      ${bindDirective}
      ${tlsDirective}
      ${requestBodyDirective}
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

    ${clusterSite}
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

    bindAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "10.0.0.2" ];
      description = ''
        LAN-facing IP address(es) each gate site binds its listener to. When
        non-empty a `bind` directive restricts every site to exactly these
        addresses, so Caddy never binds the wildcard/all-interfaces socket.

        Required whenever a gate port mirrors its loopback upstream (the default
        apiPort == apiUpstreamPort, likewise the cluster port): a wildcard bind
        also owns 127.0.0.1:PORT, and when the loopback upstream (llama-swap)
        drops its specific bind, Caddy captures loopback traffic into its own
        TLS listener ("Client sent an HTTP request to an HTTPS server"). Binding
        the LAN address guarantees loopback:PORT is answered by the upstream or
        refused, never by the gate.

        A literal is required — Caddy's `bind` takes socket addresses, not DNS
        names — so set the host's fixed LAN address. Empty keeps Caddy's default.
      '';
    };

    tlsMode = lib.mkOption {
      type = lib.types.enum [
        "route53"
        "internal"
      ];
      default = "route53";
      description = "Certificate source: Let's Encrypt DNS-01 via Route53 (ACME AWS credentials from OpenBao secrets-external/platform/acme) or Caddy's internal CA (autonomous stopgap).";
    };

    maxRequestBytes = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "2MB";
      description = "Caddy `request_body max_size` on both gated sites; a larger body gets 413 and is never forwarded. Null disables it. Rationale and sizing: ./llm-gate.md.";
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

    clusterPort = lib.mkOption {
      type = lib.types.port;
      default = 11440;
      description = "Gated cluster-mode API port on the LAN bind address (mirrors the loopback cluster port, same convention as apiPort).";
    };

    clusterUpstreamPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Loopback cluster-mode (mlx-lm rank 0) port to gate; null renders no cluster site.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = userConfig.user.name;
      description = "Login user that owns the agent, the data dir, and the secret-zero env file (the gate runs as a user LaunchAgent).";
    };

    secretZeroEnvFile = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/.local/share/llm-gate/bootstrap.env";
      description = ''
        User-owned 0600 or 0400 env file holding the gate's OpenBao secret-zero:
        BAO_ADDR and the llm-gate AppRole's LLM_GATE_VAULT_ROLE_ID /
        LLM_GATE_VAULT_SECRET_ID. openbao-run sources it unattended at each
        (re)start and logs in to fetch the gate's secrets — no Doppler
        session, no keychain (keychains cannot auto-unlock unattended; see
        header). Seeded out-of-band over ssh; openbao-run refuses the file
        unless its mode is 0600 or 0400. Rotation = rewrite the file, restart
        the agent.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/.local/share/llm-gate";
      description = "User-owned state dir (Caddy cert/config storage) and the launchd agent's WorkingDirectory.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "${userConfig.user.homeDir}/Library/Logs/llm-gate";
      description = "Log directory (access log + launchd stdout/stderr), kept OUTSIDE the 0700 dataDir so a non-root Cribl Edge can read it; macOS user-log convention.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The gate fetches its secrets from OpenBao via openbao-run (no Doppler).
    programs.openbao-run.enable = true;

    # User-owned state dir (install -d as root during activation, owned by the
    # login user so the agent — and openbao-run/Caddy — can read/write it).
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0700 "${cfg.dataDir}" "${cfg.dataDir}/data" "${cfg.dataDir}/config"
      /usr/bin/install -d -o ${cfg.user} -g staff -m 0755 "${cfg.logDir}"
    '';

    # launchd USER agent: `openbao-run` logs in with the llm-gate AppRole,
    # fetches the gate's secrets from OpenBao and injects them as env vars, then
    # execs Caddy against the secret-free Caddyfile. KeepAlive keeps it running
    # and restarts it (picking up rotated secrets on restart); no
    # RunAtLoad/PathState dance is needed because there is no sops-rendered file
    # to wait for. If the network or OpenBao is briefly unavailable at boot,
    # Caddy exits and launchd retries on the ThrottleInterval.
    launchd.user.agents.llm-gate.serviceConfig = {
      Label = "com.nix-darwin.llm-gate";
      # /bin/bash, not the Nix shebang: keeps the responsible signing identity
      # on Apple's bash, so the agent's Local Network verdict survives rebuilds
      # (a Nix binary's identity is its content hash, so it never does).
      ProgramArguments = [
        "/bin/bash"
        (lib.getExe config.programs.openbao-run.package)
        "--domain"
        "llm-gate"
        "--env-file"
        cfg.secretZeroEnvFile
      ]
      ++ lib.optionals (cfg.tlsMode == "route53") [
        "--secret"
        "secrets-external:AWS_ACME_ACCESS_KEY_ID=platform/acme#access_key_id"
        "--secret"
        "secrets-external:AWS_ACME_SECRET_ACCESS_KEY=platform/acme#secret_access_key"
        "--secret"
        "secrets-external:LLM_GATE_AWS_REGION=platform/acme#region"
      ]
      ++ [
        "--secret"
        "LLM_LARGE_BEARER_TOKEN=ai/llm#LLM_LARGE_BEARER_TOKEN"
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
        # Caddy's storage is pinned under the gate dir via XDG below. HOME is
        # kept for tools that expect it; openbao-run sources its secret-zero
        # env file by absolute path, so it needs no ~/.doppler session.
        HOME = userConfig.user.homeDir;
        XDG_DATA_HOME = "${cfg.dataDir}/data";
        XDG_CONFIG_HOME = "${cfg.dataDir}/config";
      };
      StandardOutPath = "${cfg.logDir}/llm-gate.log";
      StandardErrorPath = "${cfg.logDir}/llm-gate.error.log";
    };
  };
}
