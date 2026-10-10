# macOS VM GitHub Actions Runner (ephemeral, one Tart VM per job)
#
# khoi/sand clones a base macOS VM for each job with Tart (Apple
# Virtualization.framework), registers one ephemeral org runner inside it,
# runs the job, and destroys the VM. Job code never runs on the host, and
# every VM starts from the unmodified base image.
#
# Runs as a ROOT LaunchDaemon, not a user agent: the GitHub App private key is
# root-only by design, and a process that cannot read that key cannot register
# a runner. The VM, not the process owner, is the isolation boundary for job
# code.
#
# Operator-placed inputs (never committed here):
#   appIdFile       one line: the GitHub App's numeric App ID (root-only)
#   privateKeyPath  the App private key PEM (root-only)
# Until both exist the daemon does not start (PathState below).
#
# Installed without Homebrew: tart from nixpkgs, sshpass from nixpkgs, and sand
# from its pinned upstream release bottle. sand is not in nixpkgs, and its
# Homebrew formula is HEAD-only with a third-party tart dependency.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.macos-vm-runner;

  # tart and sshpass are found on PATH by sand; the daemon's PATH and the
  # wrapper's runtimeInputs both come from this one list.
  toolPath = lib.makeBinPath [
    pkgs.tart
    pkgs.sshpass
  ];

  # Pinned upstream bottle, not a source build: sand's only release artifacts
  # are Homebrew bottles. The binary is ad-hoc signed by the linker (no
  # Developer ID), so the pin is the sha256 of the tarball itself.
  sand = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "sand";
    version = "1.4.0"; # renovate: sand
    src = pkgs.fetchurl {
      url = "https://github.com/khoi/sand/releases/download/v${finalAttrs.version}/sand-${finalAttrs.version}.arm64_tahoe.bottle.tar.gz";
      hash = "sha256-Cx/5t9AaxLt5pZso5BRAm9Hkr4eXzpySfWDSdKD/Joc=";
    };
    sourceRoot = ".";
    dontBuild = true;
    dontConfigure = true;
    # Prebuilt Mach-O: stripping or re-signing it would break a signature the
    # kernel already accepts.
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

  # sand's config is YAML. The App ID is the one value kept out of this file:
  # it is substituted at start from appIdFile, so no identifier reaches the
  # store. The other values are JSON-quoted, which is valid YAML.
  sandTemplate = pkgs.writeText "macos-vm-runner-sand.yml.in" ''
    runners:
      - name: ${builtins.toJSON cfg.runnerName}
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
            organization: ${builtins.toJSON cfg.organization}
            privateKeyPath: ${builtins.toJSON cfg.privateKeyPath}
            runnerName: ${builtins.toJSON cfg.runnerName}
            extraLabels: ${builtins.toJSON cfg.extraLabels}
            runnerGroup: ${builtins.toJSON cfg.runnerGroup}
        healthCheck:
          command: "pgrep -fl /Users/admin/actions-runner/run.sh"
          interval: 30
          delay: 60
  '';

  runnerPkg = pkgs.writeShellApplication {
    name = "macos-vm-runner";
    runtimeInputs = [
      sand
      pkgs.tart
      pkgs.sshpass
    ];
    text = ''
      app_id="$(tr -d '[:space:]' < ${lib.escapeShellArg cfg.appIdFile})"
      if [[ ! $app_id =~ ^[0-9]+$ ]]; then
        echo "macos-vm-runner: ${cfg.appIdFile} must hold the numeric App ID" >&2
        exit 1
      fi

      # Rendered config lives under /var/run (cleared at boot), never in the store.
      runtime_dir=/var/run/macos-vm-runner
      mkdir -p "$runtime_dir"
      chmod 0700 "$runtime_dir"
      umask 077
      sed "s/@APP_ID@/$app_id/" ${sandTemplate} > "$runtime_dir/sand.yml"

      exec sand run --config "$runtime_dir/sand.yml"
    '';
  };
in
{
  options.programs.macos-vm-runner = {
    enable = lib.mkEnableOption "ephemeral macOS GitHub Actions runner in a Tart VM (khoi/sand)";

    launchdLabel = lib.mkOption {
      type = lib.types.str;
      default = "com.nix-darwin.macos-vm-runner";
      readOnly = true;
      description = "launchd label of the runner daemon. Exposed so the cluster VM-runner gate boots out this exact job.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/cirruslabs/macos-tahoe-base@sha256:87f3aa5ce21b5c876268f233bdfecf38b4c2a8116fe9bbb718e714cbae187377"; # renovate: macos-tahoe-base
      description = ''
        OCI base VM cloned for every job. Digest-pinned: the -base image
        publishes only the `latest` tag, so the digest is the only immutable
        reference. Renovate tracks digest updates.
      '';
    };

    organization = lib.mkOption {
      type = lib.types.str;
      default = "dryvist";
      description = "GitHub organization the runner registers to.";
    };

    runnerName = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}-tart";
      defaultText = lib.literalExpression "\"\${config.networking.hostName}-tart\"";
      description = "Base runner name. sand appends a per-boot suffix, so this never collides with the Linux container runner on the same host.";
    };

    runnerGroup = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Org runner group to register into. null uses the default group. Requires no repository scope.";
    };

    extraLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "tart"
        "nix-darwin"
      ];
      description = "Labels beyond the implicit self-hosted, macOS and ARM64 set GitHub applies to every macOS runner.";
    };

    cpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "vCPU count per VM.";
    };

    memoryGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Memory per VM in GB (sand's ramGb). 8 is 8192 MB.";
    };

    appIdFile = lib.mkOption {
      type = lib.types.str;
      default = "/Library/Application Support/macos-vm-runner/app-id";
      description = "Root-only file holding the GitHub App's numeric App ID. Operator-placed.";
    };

    privateKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/Library/Application Support/macos-vm-runner/app-private-key.pem";
      description = "Root-only GitHub App private key PEM. Operator-placed; the App is single-purpose (self-hosted runners, read and write, organization scope).";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o root -g wheel -m 0700 ${lib.escapeShellArg (dirOf cfg.appIdFile)} ${lib.escapeShellArg (dirOf cfg.privateKeyPath)}
    '';

    # PathState, not RunAtLoad: the daemon starts only once the App ID and the
    # key both exist, and keeps running while they do. Starting earlier would
    # spend a crash-throttle cycle on every boot before the operator places them.
    launchd.daemons.macos-vm-runner.serviceConfig = {
      Label = cfg.launchdLabel;
      ProgramArguments = [ (lib.getExe runnerPkg) ];
      EnvironmentVariables = {
        PATH = "${toolPath}:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = "/var/root";
      };
      KeepAlive.PathState = {
        ${cfg.appIdFile} = true;
        ${cfg.privateKeyPath} = true;
      };
      ThrottleInterval = 30;
      # Interactive, as sand's own service definition sets it: launchd must not
      # throttle the CPU and I/O of the VM it runs.
      ProcessType = "Interactive";
      StandardOutPath = "/var/log/macos-vm-runner.log";
      StandardErrorPath = "/var/log/macos-vm-runner.log";
    };
  };
}
