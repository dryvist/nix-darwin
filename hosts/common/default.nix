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

  # Workstations keep macOS' automatic timezone behavior. Server hosts pin UTC
  # so the Friday 00:00 launchd schedule lands at Friday 00:00 UTC there.
  time.timeZone = if hostConfig.isServer then "UTC" else null;

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
    };

    # Dedicated APFS volumes for logical data separation (AI model caches,
    # container data). Created identically on every host that declares them in
    # lib/hosts.nix — no quota, logical partitions sharing the container's free
    # space. See modules/darwin/apps/apfs-volumes.nix.
    apfsVolumes = lib.mkIf (hostConfig ? apfsVolumes) {
      enable = true;
      inherit (hostConfig) apfsContainer;
      volumes = hostConfig.apfsVolumes;
    };

    # --- Cribl Edge (inference hosts) ---
    # Log collection agent, standalone + GitOps-managed. Shared by every host
    # that declares `mlx` (a local LLM box): the vllm-mlx log paths derive from
    # the global userConfig homeDir, so the config is identical across machines.
    # Events ship over TCP JSON to the HAProxy-fronted Stream workers, which
    # forward to the Splunk `llm` index. TCP JSON — not Cribl TCP: the
    # cribl_tcp destination is refused on a standalone node ("Destination is
    # not allowed in this deployment"; it requires a distributed deployment),
    # and TCP JSON is Cribl's documented single-instance substitute. Until the
    # Stream fleet exposes the matching tcpjson source behind HAProxy
    # (ansible-proxmox-apps#525), the persistent queue buffers events locally
    # and flushes when the port comes up. See docs/CRIBL-GITOPS.md.
    # NOTE: the local-Stream cutover (→127.0.0.1:10301) is reverted while the
    # containerized Stream's CPU/DNS issue is fixed — see cribl-stream below.
    cribl-edge = lib.mkIf (hostConfig ? mlx) {
      enable = true;
      mode = "standalone";
      standalone.configFiles = {
        # File source schema (Edge 4.18): manual mode requires `path` (a
        # directory) + `filenames` (glob allowlist) — a bare `filenames` list
        # fails validation ("should have required property 'path'") and takes
        # the whole config load down with it. Shape mirrors the stock
        # in_file_varlog entry in default/edge/inputs.yml.
        "inputs.yml" = ''
          inputs:
            in_llm_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/vllm-mlx/
              filenames:
                - vllm-mlx.log
                - vllm-mlx.error.log
              tailOnly: false
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
              type: tcpjson
              # Homelab HAProxy (FQDN), load-balanced across the Cribl Stream workers.
              # Port pending in homelab-contracts service-ports (cribl_tcpjson) +
              # HAProxy frontend + Stream tcpjson source: ansible-proxmox-apps#525.
              host: ${userConfig.logging.cribl.server}
              port: 10302
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

    # --- Cribl Stream (local egress aggregator) — DISABLED (idle) ---
    # The local-Stream cutover is reverted: cribl-edge ships directly to the
    # Proxmox HAProxy (:10300), so a local Stream listening on :10301 receives
    # nothing and sits idle. Apple `container` runs it as a lightweight VM whose
    # `--memory` is the VM's RAM allocation (not a soft cap), so running it idle
    # would tie up ~1 GB + a CPU for zero benefit — unacceptable on inference
    # hosts where RAM is reserved for MLX. Kept configured (not deleted) so
    # re-enabling is a one-line flip once the containerized Stream's CPU/DNS issue
    # is fixed and the cutover is ready — right-size cpus/memory against real load
    # THEN (the module defaults 1 cpu / 1g / 1 worker are conservative starting
    # points, not a measured requirement). To re-enable: enable = lib.mkIf
    # (hostConfig ? mlx) true. No explicit container DNS: Apple `container`
    # forwards through the vmnet gateway to the host resolver. See docs/CRIBL-GITOPS.md.
    cribl-stream = {
      enable = false;
      user = userConfig.user.name;
      inputPort = 10301;
      apiPort = 9000;
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
              host: ${userConfig.logging.cribl.server}
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

  system = {
    # --- Remove unused Apple iWork/iLife apps (all hosts) ---
    # There is no declarative nix primitive to remove a macOS-preinstalled app:
    # nix is additive, and `homebrew.onActivation.cleanup = "zap"` provably leaves
    # them (verified on jevans-ms). nix-darwin's native activation interface is the
    # declarative way to express "these must not exist". Globs cover Apple's macOS
    # 26 display-name variants (e.g. "Keynote Creator Studio.app"); the removal
    # runs as root at activation and `rm -rf` is idempotent.
    activationScripts.postActivation.text = lib.mkAfter ''
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Removing unused Apple iWork/iLife apps from /Applications..."
      rm -rf /Applications/Keynote*.app /Applications/Numbers*.app /Applications/Pages*.app /Applications/GarageBand*.app /Applications/iMovie*.app
    '';

    # --- Class-driven system defaults (server class only) ---
    # `class = "server"` (headless machines) flips a few macOS system knobs away
    # from the laptop-oriented module defaults. `mkDefault` so an explicit host
    # value still wins. `mkIf isServer` gates each: a workstation needs nothing —
    # the module defaults already match the laptop.
    nixDarwinAutoUpgrade.enable = true; # Friday 00:00 local-time launchd target; server hosts are pinned to UTC above.
    energy.wakeOnMagicPacket = lib.mkIf hostConfig.isServer (lib.mkDefault true); # Wake-on-LAN for a headless box
    networkTuning.enable = lib.mkIf hostConfig.isServer (lib.mkDefault true); # socket buffers for LAN serving
    appleSiliconTunables.energyMode = lib.mkIf hostConfig.isServer (lib.mkDefault "unmanaged"); # no High Power Mode on a desktop
  };

  # SSH sessions arrive from the workstation's Ghostty terminal; without its
  # terminfo the remote zsh init spews "can't find terminal definition for
  # xterm-ghostty" on every login. Workstations get the entry from the app
  # itself; headless hosts ship just the terminfo output.
  environment.systemPackages = lib.optionals hostConfig.isServer [ pkgs.ghostty-bin.terminfo ];
}
