# Cribl Edge Service Management
#
# Manages Cribl Edge as a Nix-built package with a declarative launchd daemon.
# No .pkg installer, no Cribl Cloud install-edge.sh — the binary comes from
# packages/cribl-edge.nix and is immutable in the Nix store. Mutable state
# (config, queues, logs) lives under cfg.dataDir (default /opt/cribl-data).
#
# Two management modes (mode option):
#
#   managed    — Fleet enrollment at first start via `cribl mode-managed-edge`
#                using credentials from the configured secrets file; Cribl
#                Cloud owns runtime configuration after enrollment.
#                FLEET POLICY: Cribl Cloud fleets are reserved for Linux
#                machines (VMs/containers/servers). Do not enroll macOS hosts.
#
#   standalone — GitOps: this module owns the node's configuration. Declarative
#                config files (standalone.configFiles) are rendered from the
#                Nix store into <dataDir>/local/edge/ on every activation —
#                the Edge-mode config tree (inputs.yml, outputs.yml,
#                pipelines/<name>/conf.yml); Edge merges it over default/edge/
#                and ignores Stream's local/cribl/ tree for I/O config. Any
#                stale fleet enrollment state is retired at startup. See
#                docs/CRIBL-GITOPS.md.
#
# Managed mode accepts a root-only (0400) KEY=value file from the caller's
# secret provider. The startScript parses it line-by-line — no `source`, no
# shell eval — and only exports recognized CRIBL_* keys.
#
# Service runs as root (temporary — revert serviceUser/serviceGroup to cribl:cribl when ready).

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.cribl-edge;

  # userConfig is not a specialArg for darwin modules (only threaded to
  # home-manager), so import it directly like hosts/common/cribl.nix does —
  # used below to resolve the codex/gemini pack file-input home paths.
  userConfig = import ../../../lib/user-config.nix;

  # Change-detection hash over everything that must reach the running daemon:
  # declarative config files AND deployed packs. Used to gate the postActivation
  # restart below and (for continuity) the plist env marker. The plist sha alone
  # hashed only configFiles, so a pack-only change would go undetected.
  declaredConfigSha = builtins.hashString "sha256" (
    builtins.toJSON {
      files = cfg.standalone.configFiles;
      packs = lib.mapAttrs (_: toString) cfg.packs;
    }
  );

  deployPackScript = pkgs.writeShellApplication {
    name = "cribl-deploy-pack";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./scripts/cribl-edge-deploy-pack.sh;
  };

  # ponytail: temporary evidence-gathering for Vikunja nix-ai#1603. Delete
  # this derivation and the launchd.daemons entry below once that ticket is
  # resolved — see the script's own header for what it answers and why.
  bootRaceProbeScript = pkgs.writeShellApplication {
    name = "cribl-edge-boot-race-probe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.perl
    ];
    text = builtins.readFile ./scripts/cribl-edge-boot-race-probe.sh;
  };

  startScript = pkgs.writeShellApplication {
    name = "cribl-edge-start";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      exec ${./scripts/cribl-edge-start.sh} \
        "${if cfg.cloud.secretsFile != null then cfg.cloud.secretsFile else "/dev/null"}" \
        "${cfg.dataDir}" \
        "${cfg.package}/opt/cribl" \
        "${cfg.cloud.group}" \
        "${cfg.mode}"
    '';
  };

  # Render each declarative standalone config file into the Nix store; the
  # activation script installs them under <dataDir>/local/edge/.
  #
  # The `edge` tree is load-bearing: Cribl Edge merges default/edge/ with
  # local/edge/ for its I/O configuration (inputs, outputs, pipelines). This
  # module originally installed into local/cribl/ — Stream's tree — and Edge
  # silently ignored it: the node ran only the default/edge/inputs.yml
  # sources and never shipped a single declared event. On an Edge node,
  # local/cribl/ holds only runtime system files (auth, cribl.inited). The
  # install below also removes any copy of each declared file from that
  # legacy location so stale I/O config can't masquerade as live.
  standaloneConfigInstall = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (relPath: text: ''
      /usr/bin/install -d -o ${cfg.serviceUser} -g ${cfg.serviceGroup} \
        "$(/usr/bin/dirname "${cfg.dataDir}/local/edge/${relPath}")"
      /usr/bin/install -m 0644 -o ${cfg.serviceUser} -g ${cfg.serviceGroup} \
        ${pkgs.writeText (builtins.replaceStrings [ "/" ] [ "-" ] relPath) text} \
        "${cfg.dataDir}/local/edge/${relPath}"
      /bin/rm -f "${cfg.dataDir}/local/cribl/${relPath}"
    '') cfg.standalone.configFiles
  );
in
{
  options.programs.cribl-edge = {
    enable = lib.mkEnableOption "Cribl Edge service management";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../../packages/cribl-edge.nix { };
      description = "The Cribl Edge package to use.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/cribl-data";
      description = "Writable volume directory for Cribl state and configuration.";
    };

    serviceUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "User to run the Cribl Edge service as.";
    };

    serviceGroup = lib.mkOption {
      type = lib.types.str;
      default = "wheel";
      description = "Group to run the Cribl Edge service as.";
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "managed"
        "standalone"
      ];
      default = "managed";
      description = ''
        managed = Cribl Cloud fleet owns runtime config (Linux-only fleet
        policy — do not enroll macOS hosts). standalone = this module owns
        config via standalone.configFiles (GitOps).
      '';
    };

    standalone = {
      configFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.lines;
        default = { };
        description = ''
          Declarative Cribl config files for standalone mode, keyed by path
          relative to <dataDir>/local/edge/ (the Edge-mode config tree that
          Cribl Edge merges over default/edge/ — NOT Stream's local/cribl/,
          which Edge ignores for I/O config). Installed on every activation.
          Cribl reloads local config changes without a daemon restart.
        '';
        example = lib.literalExpression ''
          {
            "inputs.yml" = "inputs: ...";
            "outputs.yml" = "outputs: ...";
            "pipelines/llm_logs/conf.yml" = "output: default ...";
          }
        '';
      };
    };

    cloud = {
      secretsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to a root-readable KEY=value file containing
          CRIBL_DIST_MASTER_URL or the legacy CRIBL_ORG_ID,
          CRIBL_WORKSPACE_ID, and CRIBL_TOKEN fields. Required when mode =
          "managed"; unused in standalone mode.
        '';
        example = "/run/credentials/cribl-edge.env";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "default_fleet";
        description = "Fleet group name (managed mode only).";
      };
    };

    packs = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = ''
        Cribl Edge packs to deploy declaratively.
        Key = pack name, value = derivation containing pack files.
        Use fetchzip with extension = "tar.gz" for .crbl files.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mode != "managed" || cfg.cloud.secretsFile != null;
        message = "programs.cribl-edge: cloud.secretsFile is required when mode = \"managed\".";
      }
    ];

    # Always ensure dataDir + logs subdir exist with correct ownership so the
    # launchd job can write, whether or not any packs are declared. In
    # standalone mode, also install the declarative config files.
    #
    # extraActivation, NOT postActivation: nix-darwin's activation order is
    # preActivation → extraActivation → etc → defaults → launchd →
    # postActivation. Cribl does not hot-reload config files written from
    # outside its own API, so config must be on disk BEFORE the launchd phase
    # (re)starts the daemon. With postActivation, every plist-triggered
    # restart came up on the previous generation's config, and a config-only
    # change never reached the running daemon at all until the next reboot.
    system.activationScripts.extraActivation.text = ''
      ${./scripts/cribl-edge-activate.sh} "${cfg.dataDir}" "${cfg.serviceUser}:${cfg.serviceGroup}"
      ${lib.optionalString (cfg.mode == "standalone") standaloneConfigInstall}
      ${lib.optionalString (cfg.packs != { }) (
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: src: ''
            ${deployPackScript}/bin/cribl-deploy-pack ${name} ${src} ${cfg.dataDir} ${cfg.serviceUser} ${cfg.serviceGroup}
          '') cfg.packs
        )
      )}
    '';

    launchd.daemons.cribl-edge = {
      serviceConfig = {
        Label = "com.nix-darwin.cribl-edge";
        ProgramArguments = [ "${startScript}/bin/cribl-edge-start" ];
        RunAtLoad = true;
        # Plain `KeepAlive = true` races the Nix store mount at cold boot:
        # /nix is a separate APFS volume mounted by the async RunAtLoad
        # `systems.determinate.nix-store` daemon, so ProgramArguments'
        # /nix/store/... path can be missing when launchd first spawns this
        # daemon, crashing it into the penalty box for the rest of the
        # uptime (observed both Macs, 2026-08-08 reboot). PathState makes
        # launchd itself wait for /nix/store to exist before spawning, and
        # keeps watching it — no reboot-dependent recovery needed.
        KeepAlive.PathState."/nix/store" = true;
        ThrottleInterval = 10;
        UserName = cfg.serviceUser;
        GroupName = cfg.serviceGroup;
        WorkingDirectory = cfg.dataDir;
        StandardOutPath = "${cfg.dataDir}/logs/cribl-stdout.log";
        StandardErrorPath = "${cfg.dataDir}/logs/cribl-stderr.log";
        # Cribl does not hot-reload config written from outside its own API
        # (see the extraActivation note above), so a config-only generation
        # left the running daemon on stale config until reboot. Hashing the
        # declared config into the plist makes nix-darwin's launchd phase
        # restart the daemon exactly when config content changes — the env
        # var itself is inert to Cribl.
        EnvironmentVariables = {
          CRIBL_DECLARED_CONFIG_SHA256 = declaredConfigSha;
          # Let the codex/gemini pack file inputs resolve their
          # $CODEX_HOME/$GEMINI_HOME transcript paths from the Edge process env.
          CODEX_HOME = "${userConfig.user.homeDir}/.codex";
          GEMINI_HOME = userConfig.user.homeDir;
        };
      };
    };

    # ponytail: temporary, see bootRaceProbeScript's definition above and its
    # own header. Gated on the SAME KeepAlive.PathState the fixed cribl-edge
    # daemon uses, so this probe launches under identical conditions and
    # measures the thing the ticket actually needs: once that gate fires, how
    # long (if any) until the specific store path resolves? RunAtLoad with no
    # extra KeepAlive beyond the path gate, so it fires once and never again.
    launchd.daemons.cribl-edge-boot-race-probe = {
      serviceConfig = {
        Label = "com.nix-darwin.cribl-edge-boot-race-probe";
        ProgramArguments = [
          "${bootRaceProbeScript}/bin/cribl-edge-boot-race-probe"
          "${startScript}/bin/cribl-edge-start"
        ];
        RunAtLoad = true;
        KeepAlive.PathState."/nix/store" = true;
        StandardOutPath = "/var/log/cribl-boot-race-probe.log";
        StandardErrorPath = "/var/log/cribl-boot-race-probe.log";
      };
    };

    # Edge ships all Mac-origin telemetry; if it crash-loops into launchd's
    # penalty box a config-unchanged `darwin-rebuild switch` won't restart it
    # and ingestion goes dark silently. Self-heal it after every activation.
    # See modules/darwin/launchd-self-heal.nix + docs/LAUNCHD-SELF-HEAL.md.
    services.launchdSelfHeal.labels = [ "com.nix-darwin.cribl-edge" ];

    # Force the running daemon onto the just-installed config. extraActivation
    # writes local/edge/*.yml before the launchd phase, but the launchd phase
    # does not reliably restart Edge on the plist sha change, and a running Edge
    # autosaves stale in-memory config over local/edge/ — so config changes
    # never reached the daemon. This runs AFTER the launchd phase (current-gen
    # plist loaded) and restarts only when the declared config/packs actually
    # changed. See the script header for the full rationale.
    system.activationScripts.postActivation.text = ''
      ${./scripts/cribl-edge-restart-on-change.sh} "${cfg.dataDir}" "${declaredConfigSha}" "com.nix-darwin.cribl-edge" "${cfg.serviceUser}:${cfg.serviceGroup}"
    '';
  };
}
