# macOS VM GitHub Actions Runner (ephemeral, one Tart VM per job)
#
# khoi/sand clones a base macOS VM for each job with Tart (Apple
# Virtualization.framework), registers one ephemeral org runner inside it,
# runs the job, and destroys the VM. Job code never runs on the host, and
# every VM starts from the unmodified base image.
#
# Runs as a LaunchDaemon under a hidden service account, not as root, and not
# as the operator. That account owns the App ID file, the App key, the Tart VM
# store (TART_HOME) and sand's cache under its state directory. The VM is the
# isolation boundary for job code.
#
# Runtime constraint, UNVERIFIED on the target host. Tart's FAQ says that from
# macOS 15 Virtualization.framework needs an unlocked login.keychain, which
# exists and unlocks only in a GUI user session, and that without one a VM
# fails with "Interaction is not allowed with the Security Server"
# (https://tart.run/faq/, section "Headless machines"). A service account has
# no login session. Apple DTS says a VM started from a launchd daemon is not
# daemon-safe, because Virtualization links AppKit
# (https://developer.apple.com/forums/thread/841688). If VMs fail to start under
# this account, the daemon topology is the cause, not the uid.
#
# Operator-placed inputs (never committed here), owned by the service account
# with mode 0400:
#   appIdFile       one line: the GitHub App's numeric App ID
#   privateKeyPath  the App private key PEM
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

  # Hidden, non-admin service account the runner daemon runs as. The
  # underscore prefix is the macOS convention for service accounts.
  serviceUser = "_macos-vm-runner";

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
  #
  # One entry per VM. sand clones each entry under its own name (the Tart VM
  # name), so the names must differ.
  runnerEntry =
    i:
    let
      name = builtins.toJSON "${cfg.runnerName}-${toString i}";
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
            organization: ${builtins.toJSON cfg.organization}
            privateKeyPath: ${builtins.toJSON cfg.privateKeyPath}
            runnerName: ${name}
            extraLabels: ${builtins.toJSON cfg.extraLabels}
            runnerGroup: ${builtins.toJSON cfg.runnerGroup}
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
    ];
    runtimeEnv = {
      MACOS_VM_RUNNER_APP_ID_FILE = cfg.appIdFile;
      MACOS_VM_RUNNER_STATE_DIR = cfg.stateDir;
      MACOS_VM_RUNNER_SAND_TEMPLATE = "${sandTemplate}";
    };
    text = builtins.readFile ../scripts/macos-vm-runner.sh;
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
      description = "Base runner name. Entry n is `<runnerName>-<n>`, and sand appends a per-boot suffix, so names never collide with the Linux container runner on the same host.";
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

    # ponytail: one sand process runs every entry, and an error from one entry
    # propagates out of sand's task group and ends sand for all of them; launchd
    # restarts it after ThrottleInterval. Upgrade: one daemon per runner.
    runnerCount = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Runner VMs kept running at once, each an entry in sand's runners list. Capped at two by the assertion below.";
    };

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 402;
      description = "uid of the service account. Must be free on the host: nix-darwin skips an existing account whose uid differs rather than failing, so check `dscl . -list /Users UniqueID` before the first activation.";
    };

    gid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 402;
      description = "gid of the service account's own group. Must be free on the host (same skip behaviour as uid).";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/macos-vm-runner";
      description = "Home of the service account: the Tart VM store (TART_HOME), sand's runner cache and the rendered sand config. Owned by the service account, mode 0700.";
    };

    appIdFile = lib.mkOption {
      type = lib.types.str;
      default = "/Library/Application Support/macos-vm-runner/app-id";
      description = "File holding the GitHub App's numeric App ID, owned by the service account with mode 0400. Operator-placed.";
    };

    privateKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/Library/Application Support/macos-vm-runner/app-private-key.pem";
      description = "GitHub App private key PEM, owned by the service account with mode 0400. Operator-placed; the App is single-purpose (self-hosted runners, read and write, organization scope).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.runnerCount <= 2;
        message = "programs.macos-vm-runner.runnerCount is ${toString cfg.runnerCount}; Apple's macOS Software License Agreement allows at most two macOS VMs per Apple-branded host.";
      }
    ];

    # Service account and its group. Declared the way the retired agent
    # identities were: knownUsers/knownGroups must list the name, or nix-darwin
    # never creates it. Removing the name later deletes the account and home.
    users = {
      knownUsers = [ serviceUser ];
      knownGroups = [ serviceUser ];
      users.${serviceUser} = {
        inherit (cfg) uid gid;
        home = cfg.stateDir;
        description = "macOS VM runner (ephemeral Tart VMs)";
        isHidden = true;
      };
      groups.${serviceUser}.gid = cfg.gid;
    };

    # The key directory is root-owned and traversable: the service account reads
    # the two files it holds, and cannot create or replace them.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o root -g wheel -m 0755 ${lib.escapeShellArg (dirOf cfg.appIdFile)} ${lib.escapeShellArg (dirOf cfg.privateKeyPath)}
      /usr/bin/install -d -o ${serviceUser} -g ${serviceUser} -m 0700 ${lib.escapeShellArg cfg.stateDir}
    '';

    # PathState, not RunAtLoad: the daemon starts only once the App ID and the
    # key both exist, and keeps running while they do. Starting earlier would
    # spend a crash-throttle cycle on every boot before the operator places them.
    launchd.daemons.macos-vm-runner.serviceConfig = {
      Label = cfg.launchdLabel;
      ProgramArguments = [ (lib.getExe runnerPkg) ];
      UserName = serviceUser;
      GroupName = serviceUser;
      EnvironmentVariables = {
        PATH = "${toolPath}:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = cfg.stateDir;
        # Tart keeps VM images under TART_HOME, which defaults to ~/.tart.
        TART_HOME = "${cfg.stateDir}/tart";
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
