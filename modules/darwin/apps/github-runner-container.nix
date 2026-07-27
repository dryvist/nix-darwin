# GitHub Actions Self-Hosted Runner (Apple container)
#
# Runs an EPHEMERAL GitHub Actions org runner inside an Apple `container`
# (v1.0) Linux VM: the shared apple-container-runtime module brings up the
# per-user container apiserver, and a foreground `container run` under
# launchd KeepAlive supervises the runner.
#
# Script-free by design: the vendor image (myoung34/github-runner) is
# entirely env-driven — it exchanges the PAT for a registration token,
# registers, runs one job (EPHEMERAL), deregisters, and exits; KeepAlive
# then starts a fresh VM for the next job. Non-secret config rides as
# --env flags declared here; the PAT arrives via --env-file pointing at the
# sops-rendered github-runner.env (never in the plist or process args), and
# UNSET_CONFIG_VARS scrubs it from the environment before any workflow code
# runs.
#
# Event flow: the runner long-polls GitHub for jobs — no inbound webhook
# endpoint, no exposed ports. Every job executes in a brand-new Linux VM.
#
# `container` is per-user (talks to the login user's container-apiserver),
# so these are user agents, not root daemons — the server host runs with
# auto-login exactly so user agents come up unattended on boot. No --name is
# set: `--rm` cleans up normally and an anonymous name can never collide
# after a hard kill, so no pre-start delete step is needed.

{
  lib,
  config,
  ...
}:

let
  cfg = config.programs.github-runner-container;

  inherit (config.programs.apple-container-runtime) containerBin;

  runArgs = [
    containerBin
    "run"
    "--rm"
    "--cpus"
    (toString cfg.cpus)
    "--memory"
    cfg.memory
    "--env"
    "RUNNER_SCOPE=org"
    "--env"
    "ORG_NAME=${cfg.orgName}"
    "--env"
    "RUNNER_NAME=${cfg.runnerName}"
    "--env"
    "LABELS=${lib.concatStringsSep "," cfg.extraLabels}"
    "--env"
    "RUNNER_GROUP=${cfg.runnerGroup}"
    "--env"
    "EPHEMERAL=true"
    "--env"
    "DISABLE_AUTO_UPDATE=true"
    # Scrub ACCESS_TOKEN and the config vars above from the runner's
    # environment after registration, before any workflow code runs.
    "--env"
    "UNSET_CONFIG_VARS=true"
    "--env-file"
    cfg.secretsFile
  ]
  ++ [ cfg.image ]; # image must be the final positional arg
in
{
  options.programs.github-runner-container = {
    enable = lib.mkEnableOption "Ephemeral GitHub Actions org runner in an Apple container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/myoung34/github-runner:ubuntu-noble";
      description = "Env-driven runner OCI image (multi-arch; the vendor entrypoint handles PAT→token exchange, registration, and ephemeral teardown).";
    };

    orgName = lib.mkOption {
      type = lib.types.str;
      default = "dryvist";
      description = "GitHub organization the runner registers to (RUNNER_SCOPE=org).";
    };

    runnerName = lib.mkOption {
      type = lib.types.str;
      description = "Runner name shown in the org runner list (convention: the host's hostName).";
    };

    extraLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "apple-container"
        "mlx"
      ];
      description = "Labels beyond the implicit self-hosted/Linux/ARM64 set; route jobs with runs-on.";
    };

    runnerGroup = lib.mkOption {
      type = lib.types.str;
      default = "Default";
      description = "Org runner group (use a restricted group scoped to selected repos).";
    };

    cpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "vCPU cap for the runner VM.";
    };

    memory = lib.mkOption {
      type = lib.types.str;
      default = "8g";
      description = "Memory allocation for the runner VM (Apple container reserves this for the VM).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "macOS login user that owns the log dir and runs the lifecycle agents (Apple `container` is per-user).";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "staff";
      description = "Primary group of the login user (macOS default: staff).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/gh-runner";
      description = "Host directory for lifecycle logs.";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        User-readable KEY=value env file containing ACCESS_TOKEN (fine-grained
        PAT with org self-hosted-runners read/write only), consumed via
        `container run --env-file`. The current SOPS-rendered file is a
        migration bridge; OpenBao is the required end state.
      '';
      example = "/run/secrets/rendered/github-runner.env";
    };
  };

  config = lib.mkIf cfg.enable {
    # List the base dir explicitly so it gets user ownership too (install -d
    # would create missing parents root-owned).
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${cfg.user} -g ${cfg.group} "${cfg.dataDir}" "${cfg.dataDir}/logs"
    '';

    # Shared one-shot brings up the container runtime/apiserver (idempotent);
    # mkDefault so a host can still point the shared module elsewhere.
    programs.apple-container-runtime = {
      enable = lib.mkDefault true;
      user = lib.mkDefault cfg.user;
      group = lib.mkDefault cfg.group;
    };

    # Foreground `container run` supervised by launchd KeepAlive: the VM
    # exits after one job (EPHEMERAL) and launchd starts the next one.
    # PathState, not `true` — and NO RunAtLoad, which would spawn before the
    # boot sops render exists and strand the job in "spawn scheduled" when
    # the file-creation event lands between runs (the llm-gate 2026-07-04
    # reboot failure). PathState alone starts the agent exactly when the
    # rendered env-file exists, keeps it running while it exists, and
    # self-heals if the file reappears after a /var/run wipe.
    launchd.user.agents.gh-runner.serviceConfig = {
      Label = "com.nix-darwin.gh-runner";
      ProgramArguments = runArgs;
      KeepAlive = {
        PathState = {
          "${cfg.secretsFile}" = true;
        };
      };
      ThrottleInterval = 30;
      StandardOutPath = "${cfg.dataDir}/logs/gh-runner.log";
      StandardErrorPath = "${cfg.dataDir}/logs/gh-runner.err.log";
    };
  };
}
