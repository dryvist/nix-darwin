# mac-studio Host Configuration
#
# Apple Silicon Mac Studio (M4 Max, 128 GB RAM). Headless, always-on LAN
# inference / batch server (`class = server`).
#
# Shared system config — module imports, networking.hostName, OrbStack, the
# MLX model-server Cribl log-shipping pipeline, and server-class macOS defaults
# (Wake-on-LAN, network tuning, energyMode) — lives in ../common/default.nix.
# This file adds the host-unique bits: ComputerName, headless inference/power
# tuning, the llm-large serving gate, and the ephemeral GitHub Actions runner.

{
  config,
  hostConfig,
  lib,
  pkgs,
  ...
}:

let
  # Post-rebuild check that serving actually answers a real completion.
  # See the script header for why a status-code check is not sufficient and why
  # this does not touch Hermes.
  servingGate = pkgs.writeShellApplication {
    name = "serving-gate";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./scripts/serving-gate.sh;
  };

  userConfig = import ../../lib/user-config.nix;
  llmApiUpstreamPort = 11427;
in
{
  imports = [
    ../common/default.nix
    ./nix-prebuild.nix
  ];

  # Wall kiosk browser; server class skips the workstation cask list.
  homebrew.casks = [ "brave-browser" ];

  # ==========================================================================
  # System-Level Tuning (headless inference server)
  # ==========================================================================
  system = {
    # --- Apple Silicon Tunables ---
    appleSiliconTunables = {
      enable = true;
      # Same single knob and 28 GiB reserve as the workstation:
      #   maxLocalLlmGb 100 GiB -> wiredLimitMb 102400 MiB -> osReserveGb 28 GiB.
      # The old "headless needs no reserve" rationale (104000, ~13 GB reserve) is
      # superseded: WindowServer-starvation incidents show even an auto-login
      # headless session needs OS headroom.
      #
      # The fleet sentence that used to follow ("the resident 80B + 27B workers
      # (~74 GB) sit well under the 99 GiB L2 cap") was stale twice over: the
      # resident has been the 35B since 2026-07-27, and the per-worker limit on
      # this host is 48 GiB since 2026-08-05 (k_max=2). Current budget lives with
      # the values that define it — ../../lib/hosts/mac-studio.{nix,md}. Do not
      # restate it here; that duplication is what went stale.
      maxLocalLlmGb = 100;
      # Cluster hosts want High Power Mode: a rank that thermally throttles
      # mid-generation shows up as inexplicably slow tokens, not as an error.
      # Declared on BOTH cluster Macs so the intent is recorded in one place.
      #
      # A no-op on this model: `pmset -g custom` here reports no `powermode`
      # key, so macOS exposes no Energy Mode control on this hardware. The
      # apply script detects that and skips rather than retrying every
      # activation. Kept declared so it takes effect automatically if a future
      # macOS exposes the control, instead of being silently forgotten.
      energyMode = "high";
      # huggingfaceVolume uses the module default (/Volumes/HuggingFace) — the
      # dedicated APFS volume created by apfs-volumes, identical on every host.
    };

    # --- Resource Limits (file descriptors / processes) ---
    # Raise kern.maxfiles* + launchctl maxfiles to 524288 for large mmap'd models.
    resourceLimits.enable = true;

    # --- Energy & Sleep ---
    # Always-on: never idle-sleep on AC (module sleep.ac default = 0). Wake-on-LAN,
    # network tuning, and energyMode come from the server class in ../common.
    # Display never sleeps either — wall monitor host.
    energy = {
      enable = true;
      displaysleep = 0;
      displaysleepAc = 0;
    };

    # --- Auto-login: kept on this host only, deliberately (Vikunja #2132) ---
    # The MLX cluster rank/model-server agents and the GitHub runner
    # container are launchd USER agents, not system daemons — none of them
    # start after an unattended reboot without a logged-in session, and the
    # estate rule ("cluster automation requires ZERO AI/human steps") forbids
    # a human or an AI having to log in to bring the cluster back. FileVault
    # stays off here for the same reason (auto-login + FileVault means a
    # stranded pre-boot unlock screen, see modules/darwin/security.nix's
    # fdesetup comment). Vikunja #2132 tracks moving these to system daemons
    # so this can be removed and FileVault turned on. macbook-m4 has no such
    # dependency and had its auto-login removed.
    defaults.loginwindow.autoLoginUser = userConfig.user.name;
  };

  # Studio-only program modules, grouped under one `programs` attrset (statix
  # W20: avoid repeated top-level keys).
  programs = {
    # Headless server with no physical console visit expected between
    # reboots — opts back in to the default-off posture in
    # hosts/common/default.nix so a stuck boot or wedged sshd is still
    # recoverable over VNC.
    screenSharing.enable = true;

    # This is the ONE host running the arbiter (see
    # modules/darwin/apps/corosync-qnetd-arbiter.md): always-on server class,
    # so it is the more available of the two Macs eligible for this role.
    # corosync permits exactly one qdevice per cluster — macbook-m4 carries
    # the identical, disabled standby build.
    corosync-qnetd-arbiter.enable = true;

    # ========================================================================
    # llm-large Serving Gate (ADR: llm-large-studio-serving)
    # ========================================================================
    # Caddy terminates TLS on the LAN address and enforces the bearer token; the
    # model server stays on 127.0.0.1. Runs as a user LaunchAgent wrapped in
    # `openbao-run` — the bearer token, Route53 ACME creds, and region are pulled
    # live from OpenBao (never stored on this host or in sops; see llm-gate.nix).
    # route53 mode issues a real Let's Encrypt cert via DNS-01, so the cert covers
    # both the host FQDN and the `llm-large` service alias below and SNI succeeds
    # for either name.
    llm-gate = {
      enable = true;
      domain = "${hostConfig.hostName}.${userConfig.baseDomain}";
      tlsMode = "route53";
      # Stable service-alias → this host, so consumers reach the gate by
      # capability name rather than the host name. Placed one label directly
      # under the base domain, NOT under an internal-only subdomain: the Caddy
      # route53 resolver strips a single label to find the hosted zone, so a
      # deeper name under a subdomain the public DNS provider does not host
      # resolves to a zone it cannot write to and DNS-01 fails. One label under
      # the public zone issues cleanly, same as the host FQDN. (A future
      # public-facing capability name is tracked separately.)
      extraHostnames = [ "llm-large.${userConfig.baseDomain}" ];
      # bindAddresses is deliberately UNSET: the gate listens on all interfaces
      # and the firewall is the boundary.
      #
      # It previously pinned one interface's address. This host has interfaces
      # on two networks, the published A record points at the other one, and the
      # gate therefore refused every caller that resolved its own name while the
      # service itself was healthy. Pinning one address means the bind list and
      # DNS are two places that must agree, and nothing detects them disagreeing.
      #
      # The clustered site still mirrors its loopback service port. That
      # service's specific loopback bind keeps local HTTP callers from being
      # captured by Caddy's wildcard TLS listener. The regular API gate targets
      # the catalog-selected resident on its worker port.
      # Clustered-mode endpoint (mlx-lm rank 0 on loopback :11440, see
      # lib/hosts/mac-studio.nix clusterMode): second gated site, same
      # bearer token and cert, mirrored external:loopback port convention.
      clusterUpstreamPort = 11440;
      # Worker port declared by the local AI stack.
      apiUpstreamPort = llmApiUpstreamPort;
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
      runnerName = hostConfig.hostName;
      extraLabels = [
        hostConfig.hostName
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
  };

  # The serving gate runs last: a rebuild bounces dev.mlx-model-server, and this
  # host can come back with an orphaned worker or a wedged scheduler, neither of
  # which a status-code check detects. It warns rather than failing — activation
  # is already done by this point, so a non-zero exit would report a half-applied
  # system without fixing anything.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    SERVING_GATE_PORT=${toString llmApiUpstreamPort} ${lib.getExe servingGate} || true
  '';
}
