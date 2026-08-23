# Cribl Edge Service Management
#
# Manages Cribl Edge as a Nix-built package with a declarative launchd daemon.
# No .pkg installer, no Cribl Cloud install-edge.sh — the binary comes from
# packages/cribl-edge.nix and is immutable in the Nix store. Mutable state
# (config, queues, logs) lives under cfg.dataDir (default /opt/cribl-data).
#
# Two management modes — see the `mode` option below for the contract and
# docs/CRIBL-GITOPS.md for the standalone (GitOps) config tree. In standalone
# mode the declarative files render into <dataDir>/local/edge/ on every
# activation, and any stale fleet enrollment state is retired at startup.
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

  # Same shape as deployPackScript above: the .sh IS the program, not a payload
  # a second store script execs. writeShellApplication supplies bash + a
  # coreutils PATH and runs shellcheck over it; arguments come from the launchd
  # argv below.
  startScript = pkgs.writeShellApplication {
    name = "cribl-edge-start";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./scripts/cribl-edge-start.sh;
  };

  startArgs = lib.concatStringsSep " " (
    map (a: ''"${a}"'') [
      (if cfg.cloud.secretsFile != null then cfg.cloud.secretsFile else "/dev/null")
      cfg.dataDir
      "${cfg.package}/opt/cribl"
      cfg.cloud.group
      cfg.mode
    ]
  );

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
        # /nix is a separate APFS volume mounted by the async RunAtLoad
        # `systems.determinate.nix-store` daemon, so a bare
        # /nix/store/... argv0 is missing when launchd first spawns this
        # daemon at cold boot: launchd logs "Missing executable detected",
        # marks the service inactive, and never re-arms it (observed both
        # Macs, and again on the reboot that produced this fix). What
        # revived it 3m31s later was activation's
        # launchd-self-heal, which only runs postActivation — so absent a
        # darwin-rebuild the daemon stays dead for the rest of the uptime.
        #
        # `KeepAlive.PathState` does NOT fix this, despite two prior attempts
        # resting on the belief that it does. PathState governs
        # restart-after-exit only: it gates neither the RunAtLoad spawn nor
        # any re-arm after a spawn that failed with ENOENT. Do not re-add it.
        #
        # /bin/sh and /bin/wait4path live on the System volume and are always
        # present pre-mount. This is the same idiom nix-darwin already
        # generates for org.nixos.activate-system on this host.
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path /nix/store && exec ${startScript}/bin/cribl-edge-start ${startArgs}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
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
