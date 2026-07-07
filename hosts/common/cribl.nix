# Cribl log shipping (inference hosts) — Edge GitOps config + idle local Stream
#
# Split out of default.nix (repo file-size gate): the declarative Cribl Edge
# config tree (inputs/outputs/pipelines/packs) and the disabled local Stream
# aggregator. Imported unconditionally by ./default.nix; the Edge block gates
# itself on `hostConfig ? mlx` (a local LLM box), so non-inference hosts get
# nothing. See docs/CRIBL-GITOPS.md.

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
  programs = {
    # --- Cribl Edge (inference hosts) ---
    # Log collection agent, standalone + GitOps-managed. Shared by every host
    # that declares `mlx` (a local LLM box): the vllm-mlx log paths derive from
    # the global userConfig homeDir, so the config is identical across machines.
    # Live path: Edge ships TCP JSON to the HAProxy-fronted Cribl Stream
    # workers' in_cribl_s2s ingest (service port 10300), which forward to the
    # Splunk `llm` index. TCP JSON — not Cribl TCP: the cribl_tcp destination
    # is refused on a standalone node ("Destination is not allowed in this
    # deployment"; it requires a distributed deployment), and TCP JSON is
    # Cribl's documented single-instance substitute. The persistent queue
    # buffers events locally across any HAProxy/Stream downtime and flushes
    # when the port returns. See docs/CRIBL-GITOPS.md.
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
            # Per-AI-CLI session logs. Directories + rotation + the opt-in
            # capture wrappers come from programs.ai-cli-log-shipping
            # (enabled in ./default.nix). One input -> one dedicated tcpjson
            # output per CLI so Stream routes/enriches per service port; no
            # local pipeline — index/sourcetype stamping is Stream-side.
            # `*.log` matches the wrapper typescript plus anything a CLI's
            # own config drops into its directory.
            in_codex_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/codex/
              filenames:
                - "*.log"
              tailOnly: false
              sendToRoutes: false
              connections:
                - output: cribl_codex
            in_agy_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/agy/
              filenames:
                - "*.log"
              tailOnly: false
              sendToRoutes: false
              connections:
                - output: cribl_agy
            in_copilot_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/copilot/
              filenames:
                - "*.log"
              tailOnly: false
              sendToRoutes: false
              connections:
                - output: cribl_copilot
            in_vscode_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/vscode/
              filenames:
                - "*.log"
              tailOnly: false
              sendToRoutes: false
              connections:
                - output: cribl_vscode
        '';
        "outputs.yml" = ''
          outputs:
            cribl_stream:
              type: tcpjson
              # Homelab HAProxy (FQDN), load-balanced across the Cribl Stream
              # workers' in_cribl_s2s ingest — the live path, service port 10300.
              host: ${userConfig.logging.syslog.server}
              port: 10300
              pqEnabled: true
            # Per-AI-CLI service ports (one port per CLI so Stream keys
            # routing/enrichment off the frontend). Same HAProxy target as
            # cribl_stream; PQ buffers locally until each frontend is live.
            cribl_codex:
              type: tcpjson
              host: ${userConfig.logging.syslog.server}
              port: 10312
              pqEnabled: true
            cribl_agy:
              type: tcpjson
              host: ${userConfig.logging.syslog.server}
              port: 10313
              pqEnabled: true
            cribl_copilot:
              type: tcpjson
              host: ${userConfig.logging.syslog.server}
              port: 10314
              pqEnabled: true
            cribl_vscode:
              type: tcpjson
              host: ${userConfig.logging.syslog.server}
              port: 10315
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
      # Claude Code logs stay on the pack -> cribl_stream (:10300) path; a
      # repoint to a dedicated per-CLI port (:10311) is an optional future
      # step once the Stream side carves out a claude frontend.
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
              host: ${userConfig.logging.syslog.server}
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
}
