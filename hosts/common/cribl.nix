# Cribl log shipping (inference hosts) — Edge GitOps config + idle local Stream
#
# Split out of default.nix (repo file-size gate): the declarative Cribl Edge
# config tree (inputs/outputs/pipelines/packs) and the disabled local Stream
# aggregator. Imported unconditionally by ./default.nix; the Edge block gates
# itself on `hostConfig ? mlx` (a local LLM box), so non-inference hosts get
# nothing. See docs/CRIBL-GITOPS.md.

{
  config,
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
              # Ship through cribl_stream (:10300 in_cribl_s2s), the ONLY live
              # frontend — NOT cribl_llm (:10321), whose Stream frontend was
              # never provisioned (#1562: "events buffer locally until each
              # frontend exists"), so those events sit in the PQ forever and
              # never reach Splunk. The llm_logs pipeline stamps index=llm +
              # sourcetype locally; in_cribl_s2s force_splunk_meta is
              # fill-if-missing, so the stamp survives — same proven path as
              # in_firewall_logs below. Flip back to cribl_llm once the :10321
              # frontend lands (ansible-proxmox-apps#525).
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
            # NO prometheus scrape input here: the Cribl prometheus scraper
            # source is not allowed on a standalone Edge ("Source is not
            # allowed in this deployment" at init — same wall as the
            # cribl_tcp destination note above). The vllm-mlx /metrics
            # scrape (llm_metrics index) needs a redesign: either llm-gate
            # exposes /metrics for the homelab prometheus LXC to scrape and
            # remote_write, or the metrics ride a push path. Until then the
            # in_system_metrics + vllm-mlx log inputs above remain the
            # inference-host telemetry.
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
            # Claude Code session transcripts (~/.claude/projects/
            # <project>/<session>.jsonl, nested per project). Ships
            # natively to the dedicated :10311 claude frontend; the
            # cc-edge-claude-code pack never worked here (its
            # /home/$CLAUDE_USER default path does not exist on
            # macOS). tailOnly: pre-cutover history was already
            # indexed once via the old OrbStack path — ship appends
            # only, don't re-ingest months of transcripts.
            in_claude_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/.claude/projects/
              filenames:
                - "*.jsonl"
              recurse: true
              tailOnly: true
              sendToRoutes: false
              connections:
                - output: cribl_claude
            # Firewall unified-log tail (modules/darwin/logging.nix daemon
            # writes ndjson here). Stamped index=firewall locally; Stream's
            # in_cribl_s2s force_splunk_meta is fill-if-missing, so the stamp
            # survives to Splunk. ULS ndjson timestamps carry a UTC offset —
            # the Mac staying on local time is skew-safe. _time is arrival
            # time (live tail, bounded by the 10s poll); parse the embedded
            # timestamp field instead if backfill accuracy ever matters.
            in_firewall_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/firewall/
              filenames:
                - "*.log"
              tailOnly: false
              sendToRoutes: false
              connections:
                - pipeline: firewall_logs
                  output: cribl_stream
        ''
        # Appended only where programs.llm-gate is enabled (Studio-only
        # module): other mlx hosts get no input for a path that never exists.
        + lib.optionalString config.programs.llm-gate.enable ''
          # llm-gate JSON access log (Caddy `log` directive, llm-gate.nix).
            in_gate_access:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${config.programs.llm-gate.logDir}/
              filenames:
                - access.json
              tailOnly: false
              sendToRoutes: false
              connections:
                - output: cribl_gate
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
            # Dedicated LLM service ports (Stream routes/enriches off the
            # port). Same HAProxy target; cribl_gate idles without its input.
            # cribl_llm also idles for now: its :10321 frontend is not yet
            # provisioned, so in_llm_logs ships via cribl_stream (:10300)
            # instead — see the in_llm_logs connection note above. Kept
            # defined so re-pointing is one word once :10321 lands.
            cribl_llm:
              type: tcpjson
              host: ${userConfig.logging.syslog.server}
              port: 10321
              pqEnabled: true
            cribl_gate:
              type: tcpjson
              host: ${userConfig.logging.syslog.server}
              port: 10322
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
            cribl_claude:
              type: tcpjson
              host: ${userConfig.logging.syslog.server}
              port: 10311
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
        "pipelines/firewall_logs/conf.yml" = ''
          output: default
          functions:
            - id: eval
              filter: "true"
              conf:
                add:
                  - name: index
                    value: "'firewall'"
                  - name: sourcetype
                    value: "'macos:firewall'"
        '';
      };
      # Claude Code transcripts ship via the native in_claude_logs input ->
      # cribl_claude (:10311) above; the cc-edge-claude-code pack is not
      # deployed by this module (its /home/$CLAUDE_USER path never matched
      # a macOS home).
      packs = {
        cc-edge-the-mac-pack-io = pkgs.fetchzip {
          url = "https://github.com/JacobPEvans/cc-edge-the-mac-pack-io/releases/download/v0.3.0/cc-edge-the-mac-pack-io-v0.3.0.crbl";
          extension = "tar.gz";
          hash = "sha256-rPPAkedltxT8RWgP2xXil1o6x13HQK+SRgihuheJAks=";
          stripRoot = false;
        };
      };
    };

  };
}
