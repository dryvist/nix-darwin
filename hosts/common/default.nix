# Shared darwin (system-level) configuration
#
# Imported by every host's default.nix. Holds host-agnostic system config and
# consumes registry parameters (networking.hostName, OrbStack). Inference hosts
# (those that declare `mlx` in the registry) also get the shared vllm-mlx Cribl
# log-shipping pipeline here — it is identical across machines. Host-specific
# system config — streamline-login lists, energy / appleSiliconTunables values —
# stays in hosts/<label>/default.nix.

{
  lib,
  pkgs,
  hostConfig,
  ...
}:

let
  userConfig = import ../../lib/user-config.nix;
in
{
  imports = [
    # Darwin system modules
    ../../modules/darwin/common.nix
  ];

  # Network hostname from the per-host registry.
  networking.hostName = hostConfig.hostName;

  # SSH/Remote Login — macOS Remote Login via launchd (Settings > General > Sharing).
  services.openssh.enable = true;

  programs = {
    # Custom file extensions recognized as tar.gz archives (Finder auto-extract
    # + shell autocomplete).
    file-extensions.enable = true;

    # --- OrbStack ---
    # Container runtime as a system-level application on a dedicated APFS volume.
    # Only configured when the host enables it (headless hosts may not).
    # package.enable = false: OrbStack is installed via Homebrew cask (greedy) in
    # modules/darwin/homebrew.nix — a real /Applications copy, so TCC permissions
    # (Docker socket, Linux VM) persist across darwin-rebuild rather than breaking
    # on every /nix/store path change.
    # background.enable = false: `orb start` exits 0 in <1s; KeepAlive=true was
    # throttle-respawning it into a runningboardd assertion flood. OrbStack.app
    # manages its own startup.
    # `enable or false` tolerates a host that omits `orbstack` entirely.
    orbstack = lib.mkIf (hostConfig.orbstack.enable or false) {
      enable = true;
      package.enable = false;
      background.enable = false;
      dataVolume = {
        enable = true;
        name = hostConfig.orbstack.containerVolume;
        inherit (hostConfig.orbstack) apfsContainer;
      };
    };

    # --- Cribl Edge (inference hosts) ---
    # Log collection agent, standalone + GitOps-managed. Shared by every host
    # that declares `mlx` (a local LLM box): the vllm-mlx log paths derive from
    # the global userConfig homeDir, so the config is identical across machines.
    # Events ship over Cribl TCP to the HAProxy-fronted Stream workers (port from
    # terraform-proxmox constants service_ports.cribl_s2s) which forward to the
    # Splunk `llm` index. See docs/CRIBL-GITOPS.md.
    # NOTE: the local-Stream cutover (→127.0.0.1:10301) is reverted while the
    # containerized Stream's CPU/DNS issue is fixed — see cribl-stream below.
    cribl-edge = lib.mkIf (hostConfig ? mlx) {
      enable = true;
      mode = "standalone";
      standalone.configFiles = {
        "inputs.yml" = ''
          inputs:
            in_llm_logs:
              type: file
              disabled: false
              mode: manual
              filenames:
                - ${userConfig.user.homeDir}/Library/Logs/vllm-mlx/vllm-mlx.log
                - ${userConfig.user.homeDir}/Library/Logs/vllm-mlx/vllm-mlx.error.log
              sendToRoutes: false
              connections:
                - pipeline: llm_logs
                  output: cribl_stream
            in_system_metrics:
              type: system_metrics
              disabled: false
              sendToRoutes: false
              connections:
                - pipeline: llm_metrics
                  output: cribl_stream
        '';
        "outputs.yml" = ''
          outputs:
            cribl_stream:
              type: cribl_tcp
              # Homelab HAProxy (FQDN), load-balanced across the Cribl Stream workers.
              host: haproxy.pve.jacobpevans.com
              port: 10300
              pqEnabled: true
        '';
        # Model-server logs: the manager (Go) and its workers (Python) share
        # the same two files; sourcetype is derived per line.
        "pipelines/llm_logs/conf.yml" = ''
          output: default
          functions:
            - id: eval
              filter: "true"
              conf:
                add:
                  - name: index
                    value: "'llm'"
                  - name: sourcetype
                    value: "_raw.match(/^(INFO|DEBUG|WARNING|ERROR|CRITICAL):/) ? 'vllm:mlx' : 'llamaswap'"
        '';
        "pipelines/llm_metrics/conf.yml" = ''
          output: default
          functions:
            - id: eval
              filter: "true"
              conf:
                add:
                  - name: index
                    value: "'llm'"
                  - name: sourcetype
                    value: "'mlx:metrics'"
        '';
      };
      packs = {
        cc-edge-the-mac-pack-io = pkgs.fetchzip {
          url = "https://github.com/JacobPEvans/cc-edge-the-mac-pack-io/releases/download/v0.3.0/cc-edge-the-mac-pack-io-v0.3.0.crbl";
          extension = "tar.gz";
          hash = "sha256-rPPAkedltxT8RWgP2xXil1o6x13HQK+SRgihuheJAks=";
          stripRoot = false;
        };
      };
    };

    # --- Cribl Stream (local egress aggregator, Apple container) ---
    # Single-instance Cribl Stream in an Apple `container`: local sources ship to
    # 127.0.0.1:10301 and it forwards to the Proxmox Stream tier (haproxy:10300).
    # Resource-capped deliberately LOW (1 cpu / 1g / 1 worker) — it is a
    # passthrough forwarder, and on an inference box every GB left here is a GB
    # denied to MLX. Identical on all inference hosts; parameterize per-host only
    # if a host's log volume ever needs it.
    # No explicit container DNS: Apple `container` forwards through the vmnet
    # gateway to the host resolver, which already resolves the internal FQDN
    # used in outputs.yml (verified). See docs/CRIBL-GITOPS.md.
    cribl-stream = lib.mkIf (hostConfig ? mlx) {
      enable = true;
      user = userConfig.user.name;
      inputPort = 10301;
      apiPort = 9000;
      cpus = 1;
      memory = "1g";
      maxWorkers = 1;
      configFiles = {
        "inputs.yml" = ''
          inputs:
            in_edge_s2s:
              type: cribl_tcp
              disabled: false
              host: 0.0.0.0
              port: 10301
              sendToRoutes: false
              connections:
                - pipeline: passthrough
                  output: proxmox_stream
        '';
        "outputs.yml" = ''
          outputs:
            proxmox_stream:
              type: cribl_tcp
              # Homelab HAProxy (FQDN), load-balanced across the Proxmox Cribl Stream workers.
              host: haproxy.pve.jacobpevans.com
              port: 10300
              pqEnabled: true
              # Bounded on-disk queue: cap size and drop when full.
              pqMaxFileSize: 256 MB
              pqMaxSize: 1 GB
              pqOnBackpressure: drop
        '';
        # Passthrough for now; index/sourcetype enrichment moves here from Edge
        # once Edge is repointed (Edge captures, Stream enriches + egresses).
        "pipelines/passthrough/conf.yml" = ''
          output: default
          functions: []
        '';
      };
    };
  };

  # --- Class-driven system defaults ---
  # `class = "server"` (headless machines) flips a few macOS system knobs away
  # from the laptop-oriented module defaults. `mkDefault` so an explicit host
  # value still wins. Inlined here rather than a dedicated module: it only
  # consumes `hostConfig` (already in scope) and is a handful of settings.
  # A `workstation` needs nothing — the module defaults already match the laptop.
  # `class or "workstation"` tolerates a host that omits it (defaults to the safe
  # laptop profile) rather than throwing on the missing attr.
  system = lib.mkIf ((hostConfig.class or "workstation") == "server") {
    energy.wakeOnMagicPacket = lib.mkDefault true; # Wake-on-LAN for a headless box
    networkTuning.enable = lib.mkDefault true; # socket buffers for LAN serving
    appleSiliconTunables.energyMode = lib.mkDefault "unmanaged"; # no High Power Mode on a desktop
  };
}
