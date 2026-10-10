# Ephemeral macOS GitHub Actions runners using khoi/sand and Tart.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.macos-vm-runner;
  serviceUser = "_macos-vm-runner";
  stateDir = "/var/lib/macos-vm-runner";
  # Operator-installed files are owned by the service user and mode 0400.
  appDir = "/Library/Application Support/macos-vm-runner";
  appIdFile = "${appDir}/app-id";
  privateKeyPath = "${appDir}/app-private-key.pem";
  # sand uses the organization's default runner group; that group must block public repositories.
  launchdLabel = "com.nix-darwin.macos-vm-runner";

  sand = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "sand";
    # renovate: datasource=github-releases depName=khoi/sand versioning=loose
    version = "1.4.0";
    src = pkgs.fetchurl {
      url = "https://github.com/khoi/sand/releases/download/v${finalAttrs.version}/sand-${finalAttrs.version}.arm64_tahoe.bottle.tar.gz";
      hash = "sha256-Cx/5t9AaxLt5pZso5BRAm9Hkr4eXzpySfWDSdKD/Joc=";
    };
    sourceRoot = ".";
    dontBuild = true;
    dontConfigure = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 sand/${finalAttrs.version}/bin/sand $out/bin/sand
      install -Dm644 sand/${finalAttrs.version}/LICENSE $out/share/licenses/sand/LICENSE
      runHook postInstall
    '';
    meta = {
      description = "Ephemeral macOS CI runners on Tart VMs";
      homepage = "https://github.com/khoi/sand";
      license = lib.licenses.mit;
      platforms = lib.platforms.darwin;
      mainProgram = "sand";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  });

  runnerEntry =
    i:
    let
      name = builtins.toJSON "${config.networking.hostName}-tart-${toString i}";
    in
    ''
      - name: ${name}
        vm:
          source:
            type: oci
            image: ${builtins.toJSON cfg.image}
          hardware:
            cpuCores: ${toString cfg.cpus}
            ramGb: ${toString cfg.memoryGb}
          run:
            noGraphics: true
            noClipboard: true
        provisioner:
          type: github
          config:
            appId: @APP_ID@
            organization: "dryvist"
            privateKeyPath: ${builtins.toJSON privateKeyPath}
            runnerName: ${name}
            extraLabels: ${builtins.toJSON cfg.extraLabels}
        healthCheck:
          command: "pgrep -fl /Users/admin/actions-runner/run.sh"
          interval: 30
          delay: 60
    '';

  sandTemplate = pkgs.writeText "macos-vm-runner-sand.yml.in" (
    "runners:\n" + lib.concatMapStrings runnerEntry (lib.range 1 cfg.runnerCount)
  );

  runnerPkg = pkgs.writeShellApplication {
    name = "macos-vm-runner";
    runtimeInputs = [
      sand
      pkgs.tart
      pkgs.sshpass
      pkgs.coreutils
      pkgs.gnused
    ];
    runtimeEnv = {
      MACOS_VM_RUNNER_APP_ID_FILE = appIdFile;
      MACOS_VM_RUNNER_PRIVATE_KEY_FILE = privateKeyPath;
      MACOS_VM_RUNNER_STATE_DIR = stateDir;
      MACOS_VM_RUNNER_SAND_TEMPLATE = "${sandTemplate}";
    };
    text = builtins.readFile ../scripts/macos-vm-runner.sh;
  };
in
{
  options.programs.macos-vm-runner = {
    enable = lib.mkEnableOption "ephemeral macOS GitHub Actions runners in Tart VMs";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/cirruslabs/macos-tahoe-base@sha256:87f3aa5ce21b5c876268f233bdfecf38b4c2a8116fe9bbb718e714cbae187377"; # renovate: macos-tahoe-base
      description = "Digest-pinned OCI base image cloned for each job.";
    };

    cpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "vCPU count per VM.";
    };

    memoryGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Memory per VM in GB.";
    };

    extraLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "tart"
        "nix-darwin"
      ];
      description = "Additional GitHub runner labels.";
    };

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 402;
      description = "Free UID for the service account.";
    };

    gid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 402;
      description = "Free GID for the service account's group.";
    };

    runnerCount = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Concurrent sand runner entries; Apple hosts are capped at two VMs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.runnerCount <= 2;
        message = "programs.macos-vm-runner.runnerCount must not exceed Apple's two-VM limit.";
      }
    ];

    users = {
      knownUsers = [ serviceUser ];
      knownGroups = [ serviceUser ];
      users.${serviceUser} = {
        inherit (cfg) uid gid;
        home = stateDir;
        description = "macOS VM runner";
        isHidden = true;
      };
      groups.${serviceUser}.gid = cfg.gid;
    };

    environment.etc."newsyslog.d/macos-vm-runner.conf".text = ''
      # logfilename [owner:group] mode count size when flags
      ${stateDir}/runner.log ${serviceUser}:${serviceUser} 640 3 10240 * BJN
    '';

    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o root -g wheel -m 0755 ${lib.escapeShellArg appDir}
      /usr/bin/install -d -o ${serviceUser} -g ${serviceUser} -m 0700 ${lib.escapeShellArg stateDir}
    '';

    launchd.daemons.macos-vm-runner.serviceConfig = {
      Label = launchdLabel;
      ProgramArguments = [ (lib.getExe runnerPkg) ];
      UserName = serviceUser;
      GroupName = serviceUser;
      EnvironmentVariables = {
        PATH = "${
          lib.makeBinPath [
            pkgs.tart
            pkgs.sshpass
          ]
        }:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = stateDir;
        TART_HOME = "${stateDir}/tart";
      };
      # PathState entries are ORed; the PEM alone gates startup. The wrapper
      # waits quietly for a readable numeric App ID before starting sand.
      KeepAlive.PathState.${privateKeyPath} = true;
      ThrottleInterval = 30;
      ProcessType = "Interactive";
      # The service account cannot write /var/log; it owns its state directory.
      StandardOutPath = "${stateDir}/runner.log";
      StandardErrorPath = "${stateDir}/runner.log";
    };
  };
}
