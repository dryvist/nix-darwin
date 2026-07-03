# mac-studio Host Configuration
#
# Apple Silicon Mac Studio (M4 Max, 128 GB RAM). Headless, always-on LAN
# inference / batch server (`class = server`).
#
# Shared system config — module imports, networking.hostName, OrbStack, the
# vllm-mlx Cribl log-shipping pipeline, and server-class macOS defaults
# (Wake-on-LAN, network tuning, energyMode) — lives in ../common/default.nix.
# This file adds the host-unique bits: ComputerName, headless inference/power
# tuning, the llm-large serving gate, and the ephemeral GitHub Actions runner.

{ config, ... }:

let
  userConfig = import ../../lib/user-config.nix;
in
{
  imports = [ ../common/default.nix ];

  # nix-darwin sets HostName + LocalHostName from networking.hostName, but NOT
  # ComputerName — set it explicitly so the Finder/AirDrop name matches.
  networking.computerName = "jevans-ms";

  # ==========================================================================
  # System-Level Tuning (headless inference server)
  # ==========================================================================
  system = {
    # --- Apple Silicon Tunables ---
    appleSiliconTunables = {
      enable = true;
      # Headless: no ~25 GB GUI desktop working set, so reclaim the wired-memory
      # ceiling the laptop deliberately leaves at the OS default (0). 118000 ≈
      # 92 % of 128 GB (the module default). Benchmark on-machine.
      wiredLimitMb = 118000;
      # energyMode comes from the server class default ("unmanaged") in ../common.

      # Model cache lives on the internal 4 TB SSD, not the laptop's external
      # /Volumes/HuggingFace — this keeps the Time Machine exclusion tracking
      # the real path (the per-folder mdutil call degrades to a logged warn;
      # Spotlight indexing of ~/.cache is already benign).
      huggingfaceVolume = "${userConfig.user.homeDir}/.cache/huggingface";
    };

    # --- Resource Limits (file descriptors / processes) ---
    # Raise kern.maxfiles* + launchctl maxfiles to 524288 for large mmap'd models.
    resourceLimits.enable = true;

    # --- Energy & Sleep ---
    # Always-on: never idle-sleep on AC (module sleep.ac default = 0). Wake-on-LAN,
    # network tuning, and energyMode come from the server class in ../common.
    energy.enable = true;

    # --- Auto-login ---
    # The MLX stack, Open WebUI, and the gh-runner lifecycle are launchd USER
    # agents — a headless reboot serves nothing until a session exists. Auto-
    # login gives that session with zero prompts (enable once via GUI so macOS
    # writes the kcpassword artifact; FileVault stays off on this host).
    defaults.loginwindow.autoLoginUser = userConfig.user.name;
  };

  # Studio-only program modules, grouped under one `programs` attrset (statix
  # W20: avoid repeated top-level keys).
  programs = {
    # ========================================================================
    # llm-large Serving Gate (ADR: llm-large-studio-serving)
    # ========================================================================
    # Caddy terminates TLS on the LAN address and enforces the bearer token; the
    # model server stays on 127.0.0.1. The whole Caddyfile is a sops template
    # (secrets inline — no wrapper scripts). tlsMode "internal" is the bring-up
    # stopgap — flip to "route53" once the ACME AWS credentials land in
    # secrets/llm-large.yaml (phase 3 of the Studio bring-up).
    llm-gate = {
      enable = true;
      domain = "jevans-ms.jacobpevans.com";
      tlsMode = "internal";
    };

    # ========================================================================
    # GitHub Actions Runner (ephemeral, Apple container)
    # ========================================================================
    # Org-level runner for dryvist in a restricted runner group; jobs arrive by
    # runner long-poll (no inbound exposure, no webhook endpoint) and every job
    # executes in a fresh Linux VM. Entirely env-driven vendor image — no
    # custom scripts; the PAT rides in the sops-rendered env file. (The native
    # services.github-runners module is unusable here: it hard-asserts
    # nix.enable, which Determinate Nix keeps false.)
    github-runner-container = {
      enable = true;
      runnerName = "jevans-ms";
      extraLabels = [
        "jevans-ms"
        "apple-container"
        "mlx"
      ];
      # Restricted org runner group scoped to selected repos (created in the
      # dryvist org settings during bring-up; registration fails safe until then).
      runnerGroup = "llm-runners";
      user = userConfig.user.name;
      # Generous caps: jobs are AI coding/review tasks that mostly wait on the
      # local LLM endpoint; the VM reservation must still leave the wired-memory
      # budget to MLX.
      cpus = 6;
      memory = "16g";
      secretsFile = config.sops.templates."github-runner.env".path;
    };

    # ========================================================================
    # Nix-Managed Scheduled Claude Jobs (headless, launchd user agents)
    # ========================================================================
    # Unattended local `claude -p` runs on the Studio's own clones. The token is
    # the sops-rendered CLAUDE_CODE_OAUTH_TOKEN (placeholder until the user runs
    # `claude setup-token` and re-encrypts secrets/claude-code.yaml).
    claude-scheduled-jobs = {
      enable = true;
      user = userConfig.user.name;
      tokenFile = config.sops.secrets.CLAUDE_CODE_OAUTH_TOKEN.path;
      jobs.studio-hygiene = {
        schedule = {
          hour = 3;
          minute = 30;
        };
        prompt = ''
          You are running unattended on jevans-ms. For each git repository under
          ~/git (each <repo>/main checkout): run git fetch --all --prune; delete
          local branches whose upstream is gone and remove their worktrees; NEVER
          touch a branch or worktree with uncommitted changes or unpushed commits;
          skip anything ambiguous; print a one-line summary per repo; make no other
          changes; open no PRs.
        '';
      };
    };
  };

  # nix-prebuild: warm the darwin closure nightly so the morning
  # `darwin-rebuild switch` is a near-instant cache hit instead of a cold build.
  # Plain launchd agent (no claude, no token) — inline ProgramArguments, logs to
  # ~/Library/Logs/nix-prebuild/, Background priority.
  launchd.user.agents.nix-prebuild.serviceConfig = {
    Label = "com.nix-darwin.nix-prebuild";
    ProgramArguments = [
      "/run/current-system/sw/bin/nix"
      "build"
      "github:JacobPEvans/nix-darwin#darwinConfigurations.jevans-ms.system"
      "--no-link"
      "--print-build-logs"
    ];
    StartCalendarInterval = [
      {
        Hour = 4;
        Minute = 30;
      }
    ];
    ProcessType = "Background";
    StandardOutPath = "${userConfig.user.homeDir}/Library/Logs/nix-prebuild/nix-prebuild.log";
    StandardErrorPath = "${userConfig.user.homeDir}/Library/Logs/nix-prebuild/nix-prebuild.error.log";
    EnvironmentVariables = {
      HOME = userConfig.user.homeDir;
      PATH = "/run/current-system/sw/bin:/usr/bin:/bin";
    };
  };

  # nix-prebuild writes to its own log dir; create it with user ownership so the
  # user agent can write (claude-scheduled-jobs creates its own dir separately).
  system.activationScripts.postActivation.text = ''
    /usr/bin/install -d -o ${userConfig.user.name} -g staff "${userConfig.user.homeDir}/Library/Logs/nix-prebuild"
  '';
}
