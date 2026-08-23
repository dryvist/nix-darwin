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

  # AI-CLI transcript packs, hoisted so the same derivation both deploys as a
  # pack (provenance/UI) AND supplies its pipeline confs verbatim to the
  # worker-level pipelines below — the released .crbl stays the single source,
  # nothing is copy-pasted.
  codexPack = pkgs.fetchzip {
    url = "https://github.com/dryvist/cc-edge-codex-io/releases/download/v0.1.1/cc-edge-codex-io-v0.1.1.crbl";
    extension = "tar.gz";
    hash = "sha256-EgPHvubxZ+ey1alAtPXIueInzMpMB5gdt8E8aGkUlF0=";
    stripRoot = false;
  };
  geminiPack = pkgs.fetchzip {
    url = "https://github.com/JacobPEvans-personal/cc-edge-gemini-antigravity-io/releases/download/v0.4.1/cc-edge-gemini-antigravity-io-v0.4.1.crbl";
    extension = "tar.gz";
    hash = "sha256-VzRPBode10yLdDqmcaOhwWnTpUVmF10OwVkXZtyjGJ4=";
    stripRoot = false;
  };
in
{
  programs = {
    # --- Cribl Edge (inference hosts) ---
    # Log collection agent, standalone + GitOps-managed. Shared by every host
    # that declares `mlx` (a local LLM box): the MLX model-server log paths derive from
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
        # `filenames` patterns match against the FULL PATH, not the basename
        # (docs.cribl.io/edge/sources-file-monitor). A pattern without a
        # leading wildcard ("*.log", "access.json") silently matches
        # NOTHING — health Green, zero files tracked (verified via the local
        # API, 4.18.0; root cause of #1623). Always lead with "*/".
        "inputs.yml" = ''
          inputs:
            in_llm_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/mlx-model-server/
              filenames:
                - "*/*.log"
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
            # Clustered-mode logs (rank + link watcher + prefetch, both Macs).
            # Same proven path and pipeline as in_llm_logs above; the "*/"
            # lead on every pattern is the #1623 lesson.
            in_cluster_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Logs/mlx-cluster/
              filenames:
                - "*/cluster-*.log"
              tailOnly: false
              sendToRoutes: false
              connections:
                - pipeline: llm_logs
                  output: cribl_stream
            # Benchmark result events (mlx-benchmarks#119): mlx-bench-publish
            # appends one flat JSON line per result row; derived state,
            # replayable from the HF dataset via `mlx-bench-events replay`.
            in_bench_events:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/.local/state/mlx-benchmarks/
              filenames:
                - "*/bench-events.jsonl"
              tailOnly: false
              sendToRoutes: false
              connections:
                - pipeline: bench_events
                  output: cribl_stream
            # Whole-machine + per-process OS metrics (native system_metrics
            # Source, Edge 4.18 — host CPU/mem/disk/net plus process metrics),
            # 10s poll ≈ an always-on Activity Monitor.
            # INTERIM: routed to the llm_metrics pipeline (index=llm, EVENT) —
            # the prior behavior. Stamping the os_metrics METRIC index was tried
            # (nix-darwin#1824) but Splunk rejects it: this Edge->S2S->Stream
            # path delivers EVENT-format JSON on the legacy token, and a metric
            # index refuses event data (invalid_index). True os_metrics-as-metrics
            # needs a Stream-side metric route (ansible-proxmox-apps cribl_stream:
            # metric formatting + a per-index os_metrics token, like host_metrics).
            # Until that lands, keep the data flowing as events here.
            in_system_metrics:
              type: system_metrics
              disabled: false
              pollingInterval: 10
              sendToRoutes: false
              connections:
                - pipeline: llm_metrics
                  output: cribl_stream
            # Critical macOS logs + power/thermal telemetry -> index=os (event),
            # sourcetype macos:* (the os_events pipeline derives sourcetype from
            # __inputId). Native Sources where Edge 4.18 has them; the three exec
            # sources below (powermetrics, pmset thermal, ioreg battery) have no
            # native 4.18 equivalent. Commands taken verbatim from the
            # cc-edge-the-mac-pack-io pack. Edge runs as root here, so
            # powermetrics/ioreg/DiagnosticReports reads succeed.
            #
            # Unified Logging Subsystem, native Source.
            #
            # readMode is DELIBERATELY ABSENT. "lastEntry" is not a valid enum
            # value (the validator accepts oldest|newest only), so Cribl
            # rejected this whole input with CrudEntityInvalidError on every
            # restart -- it had never once initialized. Do not re-add it; the
            # default ("from last entry") is what was wanted anyway.
            #
            # The predicate is narrowed to the panic/thermal/jetsam signal
            # path. The previous one matched bare "watchdog"/"thermal" from
            # runningboardd/WallpaperAgent and measured 165,891 events over 3h
            # (~1.33M/day), burying the DumpPanic line that mattered; this one
            # measured 7,901 over the same window (~63k/day, 21x less) and
            # still catches it. Shipping it together with the readMode fix is
            # not optional: fixing readMode alone floods the destination.
            in_macos_unified_logs:
              type: apple_unified_logs
              disabled: false
              predicate: '(process == "kernel" AND (eventMessage CONTAINS[c] "jetsam" OR eventMessage CONTAINS[c] "memorystatus" OR eventMessage CONTAINS[c] "low swap" OR eventMessage CONTAINS[c] "memory pressure" OR eventMessage CONTAINS[c] "panic" OR eventMessage CONTAINS[c] "IOGPU" OR eventMessage CONTAINS[c] "AGX" OR eventMessage CONTAINS[c] "thermal")) OR process == "DumpPanic" OR process == "ReportCrash" OR process == "thermalmonitord" OR subsystem == "com.apple.thermalmonitord" OR eventMessage CONTAINS[c] "userspace watchdog timeout" OR eventMessage CONTAINS[c] "GPU restart" OR eventMessage CONTAINS[c] "gpu hang"'
              sendToRoutes: false
              connections:
                - pipeline: os_events
                  output: cribl_stream
            # powermetrics: the only path to per-process energy + CPU/GPU/ANE
            # power. Exec, 300s (expensive sampler). One JSON doc per sample.
            # Performance sampling, not event telemetry -> index=mac_perf.
            #
            # The `-replace timestamp -string ""` hop is load-bearing:
            # `plutil -convert json` cannot represent the <date> plist type and
            # powermetrics' fixed per-sample header always emits
            # <key>timestamp</key><date>, so every sample failed to convert.
            # `-replace` and not `-remove`: -remove hard-fails with "No value
            # to remove at key path timestamp" whenever the key is absent,
            # while -replace creates it and cannot fail.
            in_macos_powermetrics:
              type: exec
              disabled: false
              interval: 300
              command: "powermetrics --samplers tasks,battery,cpu_power,gpu_power,ane_power,thermal --show-process-energy -f plist -n 1 -i 5000 | /usr/bin/plutil -replace timestamp -string \"\" -o - - | /usr/bin/plutil -convert json -o - -"
              sendToRoutes: false
              connections:
                - pipeline: mac_perf
                  output: cribl_stream
            # Wired memory + the GPU wired ceiling (iogpu.wired_limit_mb):
            # system_metrics exposes memory_percent only, neither of these. At
            # wired has been observed at 91.3 GiB against a 100 GiB ceiling,
            # which is the signal that predicts exhaustion. Command taken VERBATIM from
            # cc-edge-the-mac-pack-io (stock binaries chained, no script file);
            # it also emits wired_ceiling_bytes on top of the four headline
            # fields. Named in_* to match this instance's inputs -- the pack
            # calls it macos-wired-memory.
            in_macos_wired_memory:
              type: exec
              disabled: false
              interval: 60
              command: "/bin/bash -c 'wp=$(/usr/bin/vm_stat | /usr/bin/awk \"/Pages wired down/{gsub(/[^0-9]/,\\\"\\\",\\$4);print \\$4}\"); pgsz=$(/usr/sbin/sysctl -n hw.pagesize); cm=$(/usr/sbin/sysctl -n iogpu.wired_limit_mb); rk=$(/bin/ps -A -o rss= | /usr/bin/awk \"{s+=\\$1} END{print s+0}\"); /usr/bin/awk -v wp=\"$wp\" -v pgsz=\"$pgsz\" -v cm=\"$cm\" -v rk=\"$rk\" \"BEGIN{wb=wp*pgsz; cb=cm*1024*1024; printf \\\"{\\\\\\\"wired_bytes\\\\\\\":%d,\\\\\\\"wired_ceiling_mb\\\\\\\":%d,\\\\\\\"wired_ceiling_bytes\\\\\\\":%d,\\\\\\\"wired_ratio\\\\\\\":%.4f,\\\\\\\"resident_bytes\\\\\\\":%d}\\\\n\\\", wb, cm, cb, wb/cb, rk*1024}\"'"
              sendToRoutes: false
              connections:
                - pipeline: mac_perf
                  output: cribl_stream
            # Thermal/perf pressure levels (pmset -g therm) — not in the native
            # System Metrics Source on macOS. Exec, 60s.
            in_macos_thermal:
              type: exec
              disabled: false
              interval: 60
              command: "pmset -g therm"
              sendToRoutes: false
              connections:
                - pipeline: os_events
                  output: cribl_stream
            # ponytail: standalone battery-health exec (pmset+ioreg) dropped —
            # its deeply-nested quoting is fragile and a mis-escape fails the
            # whole Edge config load; powermetrics' `battery` sampler above
            # already carries the basics. Re-add by wiring the pack's verbatim
            # command (not re-transcribing) if cycle-count/capacity detail is
            # wanted.
            # Crash/panic reports. File Source (manual mode: path + "*/"-led glob,
            # per the #1623 lesson). System + user DiagnosticReports dirs.
            # tailOnly: true — only NEW reports after Edge start. false backfilled
            # the entire DiagnosticReports history (~283k fragmented events).
            in_macos_crashreports_sys:
              type: file
              disabled: false
              mode: manual
              interval: 60
              path: /Library/Logs/DiagnosticReports/
              filenames:
                - "*/*.ips"
                - "*/*.panic"
                - "*/*.crash"
                - "*/*.diag"
                - "*/*.hang"
                # .spin = blocked-thread stacks, the single most diagnostic
                # artifact for a WindowServer-watchdog panic; .shutdownStall
                # marks an unclean shutdown (3 in one week, unrecorded before).
                - "*/*.spin"
                - "*/*.shutdownStall"
              # Explicit, not a behaviour change: the "*/"-led globs already
              # match at any depth (Cribl matches them against the full path),
              # so Retired/ -- where macOS moves a report once submitted or
              # aged out -- was already being read without this. Verified in
              # the live collector state: 7 entries point under Retired/,
              # every one read to EOF. Set anyway
              # so reaching that directory does not silently depend on a
              # wildcard spanning path separators.
              #
              # No duplication either way. Cribl keys file state on headHash,
              # a sha256 of the first 256 bytes, carrying iNode and fileName
              # as attributes -- so a moved report keeps its key and its
              # readPosition rather than re-ingesting. 141/141 live entries
              # are keyed that way, with 0 head-hash collisions across 180
              # artifacts.
              recurse: true
              tailOnly: true
              sendToRoutes: false
              breakerRulesets:
                - MacOS Crash Reports
              connections:
                - pipeline: os_events
                  output: cribl_stream
            in_macos_crashreports_user:
              type: file
              disabled: false
              mode: manual
              interval: 60
              path: ${userConfig.user.homeDir}/Library/Logs/DiagnosticReports/
              filenames:
                - "*/*.ips"
                - "*/*.panic"
                - "*/*.crash"
                - "*/*.diag"
                - "*/*.hang"
                # .spin = blocked-thread stacks, the single most diagnostic
                # artifact for a WindowServer-watchdog panic; .shutdownStall
                # marks an unclean shutdown (3 in one week, unrecorded before).
                - "*/*.spin"
                - "*/*.shutdownStall"
              tailOnly: true
              sendToRoutes: false
              breakerRulesets:
                - MacOS Crash Reports
              connections:
                - pipeline: os_events
                  output: cribl_stream
            # NO prometheus scrape input here: the Cribl prometheus scraper
            # source is not allowed on a standalone Edge ("Source is not
            # allowed in this deployment" at init — same wall as the
            # cribl_tcp destination note above). MLX model-server metrics
            # scrape (llm_metrics index) needs a redesign: either llm-gate
            # exposes /metrics for the homelab prometheus LXC to scrape and
            # remote_write, or the metrics ride a push path. Until then the
            # in_system_metrics + MLX model-server log inputs above remain the
            # inference-host telemetry.
            # Per-AI-CLI session logs. Directories + rotation + the opt-in
            # capture wrappers come from programs.ai-cli-log-shipping
            # (enabled in ./default.nix). One input -> one dedicated tcpjson
            # output per CLI so Stream routes/enriches per service port; no
            # local pipeline — index/sourcetype stamping is Stream-side.
            # `*.log` matches the wrapper typescript plus anything a CLI's
            # own config drops into its directory.
            # codex + gemini transcripts now ship via their cc-edge packs (see
            # the packs block below), not banner-log file inputs — the old
            # in_codex_logs/in_agy_logs inputs tailed ~/Library/Logs/{codex,agy}
            # and were removed. copilot + vscode below still use the banner path.
            #
            # Pack-feeder inputs: this standalone Edge never instantiates a
            # pack's own default/inputs.yml Sources (live-verified — the worker
            # only initializes worker-level inputs), and QuickConnecting into
            # `pack:<id>` ships events UNPROCESSED (the pack-internal routing
            # layer never loads here; the live API serves every pack a
            # fallback filter:true -> pipeline:main route). So the pack file
            # inputs are declared HERE and QuickConnected straight into the
            # pack pipelines, which are installed as worker-level pipelines
            # from the released pack derivations (see the pipelines/*
            # configFiles below).
            in_codex_sessions:
              type: file
              disabled: false
              mode: manual
              interval: 30
              path: ${userConfig.user.homeDir}/.codex/sessions
              filenames:
                - "*/rollout-*.jsonl"
              recurse: true
              tailOnly: false
              sendToRoutes: false
              breakerRulesets:
                - AI CLI JSONL
              metadata:
                - name: datatype
                  value: "'codex-cli-session'"
              connections:
                - pipeline: codex_sessions
                  output: cribl_codex
            in_codex_history:
              type: file
              disabled: false
              mode: manual
              interval: 30
              path: ${userConfig.user.homeDir}/.codex
              filenames:
                - "*/history.jsonl"
              recurse: false
              tailOnly: false
              sendToRoutes: false
              breakerRulesets:
                - AI CLI JSONL
              metadata:
                - name: datatype
                  value: "'codex-cli-history'"
              connections:
                - pipeline: codex_history
                  output: cribl_codex
            in_gemini_sessions:
              type: file
              disabled: false
              mode: manual
              interval: 30
              path: ${userConfig.user.homeDir}/.gemini/tmp
              filenames:
                - "*session-*.json"
                - "*session-*.jsonl"
              recurse: true
              tailOnly: true
              sendToRoutes: false
              breakerRulesets:
                - AI CLI JSONL
              metadata:
                - name: datatype
                  value: "'gemini-cli-session'"
              connections:
                - pipeline: llm_normalize
                  output: cribl_agy
            in_antigravity_transcripts:
              type: file
              disabled: false
              mode: manual
              interval: 60
              path: ${userConfig.user.homeDir}/.gemini/antigravity-cli/brain
              filenames:
                - "*/transcript_full.jsonl"
              recurse: true
              tailOnly: false
              sendToRoutes: false
              breakerRulesets:
                - AI CLI JSONL
              metadata:
                - name: datatype
                  value: "'antigravity-cli-transcript'"
              connections:
                - pipeline: llm_normalize
                  output: cribl_agy
            in_antigravity_history:
              type: file
              disabled: false
              mode: manual
              interval: 30
              path: ${userConfig.user.homeDir}/.gemini/antigravity-cli
              filenames:
                - "*history.jsonl"
              recurse: false
              tailOnly: true
              sendToRoutes: false
              breakerRulesets:
                - AI CLI JSONL
              metadata:
                - name: datatype
                  value: "'antigravity-cli-history'"
              # v0.4.1 llm_normalize stamps history's sourcetype/index too (its
              # llm.* evals gate on fields history lacks, so they skip it).
              connections:
                - pipeline: llm_normalize
                  output: cribl_agy
            # The copilot input is deliberately absent. It watched a directory
            # the CLI creates once and never writes to, and the tool keeps no
            # on-disk log elsewhere. An input on a never-written path is not
            # collection: it reads as configured while delivering nothing,
            # which is worse than having no input at all, because it answers
            # "is this wired up" with a yes. Restore it only together with a
            # verified path the tool actually writes.
            #
            # VS Code writes per-session logs under Application Support, not
            # under Library/Logs, which is why the previous path stayed empty.
            # Sessions are timestamped directories, so the search descends one
            # level and picks up sessions created after the collector starts.
            in_vscode_logs:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${userConfig.user.homeDir}/Library/Application Support/Code/logs/
              # GitLens.log is excluded on timestamp grounds, not volume. Its
              # lines carry two stamps in different zones: GitLens' own in
              # local time, plus a bracketed UTC one belonging to the wrapped
              # Git extension message. Continuation lines begin with the
              # bracketed UTC form alone, which gets read as local time and
              # lands the event +4h in the future. Measured over 24h on
              # 2026-08-06: 120 GitLens.log events skewed up to +3.9h, against
              # ~293k events from every other VS Code log at or slightly
              # behind index time.
              #
              # A future-dated event is blinding, not merely wrong: it pulls
              # latest(_time) ahead of now across the whole index, so the
              # surface reads as perpetually fresh and no staleness detector
              # can ever fire on VS Code — 120 events suppressing the signal
              # from 293k. No timezone setting repairs it, since the two forms
              # really are in separate zones inside one file.
              #
              # Nothing is lost: these lines are the Git extension's own
              # output, collected correctly already from Git.log. Leading "*"
              # makes the pattern match the full path (Cribl matches filename
              # patterns against the full path, never the basename) at any
              # directory depth.
              filenames:
                - "*.log"
                - "!*GitLens.log"
              recurse: true
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
          # Full-path-matched pattern — must lead with "*/" (see above).
            in_gate_access:
              type: file
              disabled: false
              mode: manual
              interval: 10
              path: ${config.programs.llm-gate.logDir}/
              filenames:
                - "*/access.*"
                # Clustered-mode site's own access log (llm-gate clusterSite).
                - "*/cluster-access.*"
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
            # The copilot destination is removed with its input: nothing feeds
            # it, and a persistent-queue output with no source is a place for
            # events to accumulate unseen if one is ever connected by accident.
            # Its ingest port stays reserved upstream, so restoring both halves
            # later is additive.
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
      }
      // import ./cribl-pipelines.nix { inherit codexPack geminiPack; };
      # Claude Code transcripts ship via the native in_claude_logs input ->
      # cribl_claude (:10311) above; the cc-edge-claude-code pack is not
      # deployed by this module (its /home/$CLAUDE_USER path never matched
      # a macOS home).
      # codex + gemini transcripts ship via their cc-edge packs below instead
      # of banner-log inputs: each pack tails the real transcript path (codex
      # under $CODEX_HOME, gemini under $GEMINI_HOME/.gemini — env vars set on
      # the Edge process in modules/darwin/apps/cribl-edge.nix), normalizes to
      # OTel-AI llm.* fields, stamps index/sourcetype, and routes to the
      # default output.
      packs = {
        cc-edge-the-mac-pack-io = pkgs.fetchzip {
          url = "https://github.com/JacobPEvans/cc-edge-the-mac-pack-io/releases/download/v0.3.0/cc-edge-the-mac-pack-io-v0.3.0.crbl";
          extension = "tar.gz";
          hash = "sha256-rPPAkedltxT8RWgP2xXil1o6x13HQK+SRgihuheJAks=";
          stripRoot = false;
        };
        cc-edge-codex-io = codexPack;
        cc-edge-gemini-antigravity-io = geminiPack;
      };
    };

  };
}
