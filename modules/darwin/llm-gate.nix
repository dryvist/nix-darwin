# llm-large L7 Gate (launchd Caddy)
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
# Fully declarative — no wrapper scripts: the ENTIRE Caddyfile is a sops-nix
# template rendered at activation with the secrets inline (bearer token and,
# in route53 mode, ACME credentials), root-only 0400 under
# /run/secrets/rendered/. The launchd daemon execs Caddy directly against
# that rendered path, so it comes up on boot and survives reboots with zero
# interactive prompts (hard requirement for the headless server). Caddy binds
# all interfaces — no bind address exists anywhere, so no address octets land
# in this public repo (see the config comment below).
#
# TLS modes:
#   route53  — real Let's Encrypt cert via DNS-01 against the public zone,
#              using the same least-privilege `acme` AWS user Traefik already
#              uses for *.pve ingress (credentials inline in the tls block).
#   internal — Caddy's local CA (autonomous, no external dependency); clients
#              must trust the CA or skip verification. Bring-up stopgap until
#              the ACME credentials are provisioned.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.llm-gate;

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

  tlsDirective =
    if cfg.tlsMode == "route53" then
      ''
        tls {
              dns route53 {
                access_key_id "${config.sops.placeholder."LLM_GATE_AWS_ACCESS_KEY_ID"}"
                secret_access_key "${config.sops.placeholder."LLM_GATE_AWS_SECRET_ACCESS_KEY"}"
                region "${config.sops.placeholder."LLM_GATE_AWS_REGION"}"
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
      description = "Certificate source: Let's Encrypt DNS-01 via Route53 (needs the ACME AWS credentials in secrets/llm-large.yaml) or Caddy's internal CA (autonomous stopgap).";
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

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llm-gate";
      description = "Writable state directory (certificates, Caddy storage, logs).";
    };
  };

  config = lib.mkIf cfg.enable {
    # The whole Caddyfile is the rendered secret: the bearer token and
    # (route53 mode) ACME credentials are substituted by sops-nix at
    # activation. No bind directive: Caddy binds all interfaces (identical
    # exposure to the LAN address on a single-NIC host), which keeps address
    # octets out of config entirely and survives VLAN/IP moves with zero
    # secret rotations. {$VAR} env substitution and wrapper scripts are
    # unnecessary.
    sops.templates."llm-gate.Caddyfile" = {
      owner = "root";
      group = "wheel";
      mode = "0400";
      content = ''
        {
          admin off
          auto_https disable_redirects
        }

        ${apiSiteAddresses} {
          ${tlsDirective}
          @unauthorized not header Authorization "Bearer ${
            config.sops.placeholder."LLM_LARGE_BEARER_TOKEN"
          }"
          respond @unauthorized 401
          reverse_proxy 127.0.0.1:${toString cfg.apiUpstreamPort}
        }
      '';
    };

    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o root -g wheel -m 0700 "${cfg.dataDir}" "${cfg.dataDir}/data" "${cfg.dataDir}/config" "${cfg.dataDir}/logs"
    '';

    launchd.daemons.llm-gate = {
      serviceConfig = {
        Label = "com.nix-darwin.llm-gate";
        ProgramArguments = [
          (lib.getExe caddyPkg)
          "run"
          "--config"
          config.sops.templates."llm-gate.Caddyfile".path
          "--adapter"
          "caddyfile"
        ];
        # NO RunAtLoad: it defeats KeepAlive.PathState. RunAtLoad spawns the
        # job at boot BEFORE the sops render exists — caddy exits 78
        # (EX_CONFIG), and because the config file's creation event fires
        # while the job is between runs, launchd never re-evaluates and the
        # daemon sits in "spawn scheduled" forever (observed on the
        # 2026-07-04 reboot, runs=1). With PathState alone, launchd starts
        # the daemon exactly when the rendered Caddyfile exists, keeps it
        # running while it exists, and respawns it whenever the file
        # reappears — which also self-heals after any mid-uptime /var/run
        # wipe. The Caddyfile is sops-rendered under /run/secrets
        # (= /private/var/run), which macOS clears at boot.
        KeepAlive = {
          PathState = {
            "${config.sops.templates."llm-gate.Caddyfile".path}" = true;
          };
        };
        ThrottleInterval = 15;
        UserName = "root";
        GroupName = "wheel";
        WorkingDirectory = cfg.dataDir;
        EnvironmentVariables = {
          HOME = cfg.dataDir;
          XDG_DATA_HOME = "${cfg.dataDir}/data";
          XDG_CONFIG_HOME = "${cfg.dataDir}/config";
        };
        StandardOutPath = "${cfg.dataDir}/logs/llm-gate.log";
        StandardErrorPath = "${cfg.dataDir}/logs/llm-gate.error.log";
      };
    };
  };
}
