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
#                using credentials from the sops-rendered secrets file; Cribl
#                Cloud owns runtime configuration after enrollment.
#                FLEET POLICY: Cribl Cloud fleets are reserved for Linux
#                machines (VMs/containers/servers). Do not enroll macOS hosts.
#
#   standalone — GitOps: this module owns the node's configuration. Declarative
#                config files (standalone.configFiles) are rendered from the
#                Nix store into <dataDir>/local/cribl/ on every activation —
#                the config-as-code layout documented by Cribl (inputs.yml,
#                outputs.yml, pipelines/<name>/conf.yml). Any stale fleet
#                enrollment state is retired at startup. See docs/CRIBL-GITOPS.md.
#
# Secrets are provided via sops-nix (modules/darwin/sops.nix), which decrypts
# age-encrypted credentials to a root-only (0400) KEY=value file at activation
# time. The startScript parses this file line-by-line — no `source`, no shell
# eval — and only exports recognized CRIBL_* keys. (Managed mode only.)
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

  deployPackScript = pkgs.writeShellApplication {
    name = "cribl-deploy-pack";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./scripts/cribl-edge-deploy-pack.sh;
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
  # activation script installs them under <dataDir>/local/cribl/.
  standaloneConfigInstall = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (relPath: text: ''
      /usr/bin/install -d -o ${cfg.serviceUser} -g ${cfg.serviceGroup} \
        "$(/usr/bin/dirname "${cfg.dataDir}/local/cribl/${relPath}")"
      /usr/bin/install -m 0644 -o ${cfg.serviceUser} -g ${cfg.serviceGroup} \
        ${pkgs.writeText (builtins.replaceStrings [ "/" ] [ "-" ] relPath) text} \
        "${cfg.dataDir}/local/cribl/${relPath}"
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
          relative to <dataDir>/local/cribl/ (the config-as-code location
          documented by Cribl). Installed on every activation. Cribl reloads
          local config changes without a daemon restart.
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
          Path to a root-readable KEY=value file containing CRIBL_ORG_ID,
          CRIBL_WORKSPACE_ID, and CRIBL_TOKEN. Use the sops-nix rendered
          template: config.sops.templates."cribl-edge.env".path
          Required when mode = "managed"; unused in standalone mode.
        '';
        example = "/run/secrets/rendered/cribl-edge.env";
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
    system.activationScripts.postActivation.text = ''
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
        KeepAlive = true;
        ThrottleInterval = 10;
        UserName = cfg.serviceUser;
        GroupName = cfg.serviceGroup;
        WorkingDirectory = cfg.dataDir;
        StandardOutPath = "${cfg.dataDir}/logs/cribl-stdout.log";
        StandardErrorPath = "${cfg.dataDir}/logs/cribl-stderr.log";
      };
    };
  };
}
