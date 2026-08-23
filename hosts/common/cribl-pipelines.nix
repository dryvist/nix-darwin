# Cribl Edge worker-level pipelines + event breakers (standalone GitOps config)
#
# Split out of ./cribl.nix for the repo file-size gate; merged straight back
# into `programs.cribl-edge.standalone.configFiles` there. Pure data — the
# only inputs are the two released AI-CLI pack derivations whose pipeline
# confs are installed verbatim.

{ codexPack, geminiPack }:

{
  # Model-server logs: the manager (Go) and its workers (Python) share
  # the same two files. Keep the worker sourcetype backend-neutral so a
  # selected MLX server change does not require downstream rewrites.
  # in_cluster_logs (rank/watcher/peer-liveness) shares this same
  # pipeline but is a third, unrelated event shape — discriminate on
  # __inputId FIRST (same pattern as os_events below), or its lines
  # fall through the content regex and land mislabeled as
  # mlx:model-server, indistinguishable from real worker output
  # (verified live: thousands of cluster-watcher decision lines tagged
  # mlx:model-server before this fix).
  #
  # None of the three source formats carries a timestamp Cribl can
  # reliably parse at the line start (llama-swap's own `[INFO] Request
  # ...` access lines and the cluster-watcher lines have no leading
  # timestamp at all), so _time for llamaswap and mlx:cluster is
  # arrival/index time — same honest, already-documented pattern used
  # for firewall_logs below. Only the Python worker lines (mlx:model-server)
  # carry a real per-line timestamp, which Cribl parses natively.
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
              value: "String(__inputId).includes('cluster') ? 'mlx:cluster' : _raw.match(/^(\\[(DEBUG|INFO|WARN|ERROR)\\] |time=[^ ]+ level=(DEBUG|INFO|WARN|ERROR) |[0-9]{4}[/][0-9]{2}[/][0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/) ? 'llamaswap' : 'mlx:model-server'"
  '';
  "pipelines/bench_events/conf.yml" = ''
    output: default
    functions:
      - id: eval
        filter: "true"
        conf:
          add:
            - name: index
              value: "'llm'"
            - name: sourcetype
              value: "'mlx:bench'"
  '';
  # system_metrics -> index=llm (EVENT), sourcetype mlx:metrics. INTERIM
  # (see in_system_metrics above): the os_metrics METRIC-index route was
  # reverted because this S2S path ships event-format data that a metric
  # index rejects. Restore os_metrics here once the Stream side formats
  # these as Splunk metrics via a per-index os_metrics token.
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
  # Critical macOS event telemetry -> index=os. sourcetype is derived
  # from __inputId, one explicit branch per wired Source. The fallback is
  # a visible sentinel and NOT 'macos:unifiedlog': the old unguarded
  # chain silently relabelled anything unmatched as unified-log data, so
  # a mis-wired Source looked correct in Splunk. An unmatched event now
  # shows up as unmatched.
  "pipelines/os_events/conf.yml" = ''
    output: default
    functions:
      - id: eval
        filter: "true"
        conf:
          add:
            - name: index
              value: "'os'"
            - name: sourcetype
              value: "String(__inputId).includes('unified_logs') ? 'macos:unifiedlog' : String(__inputId).includes('crashreports') ? 'macos:crashreport' : String(__inputId).includes('thermal') ? 'macos:thermal' : 'macos:unmatched'"
      # Crash reports carry their own event time. Without this, _time is
      # whenever Edge happened to read the file: accurate when it reads live,
      # but hours to a day late whenever a report is picked up on restart or
      # backfill -- which is what happens whenever Edge is not running for
      # the first stretch after a reboot. Alerting on arrival still works;
      # correlating a report against host state at the moment it was written
      # does not.
      #
      # Two header shapes cover .ips (JSON header line, "timestamp") and
      # .spin/.diag (plain-text "Date/Time:" header). .shutdownStall is a
      # base64 spindump with no in-band timestamp and always takes the
      # fallback. An event is never dropped for a missing timestamp -- an
      # imprecise crash report beats a lost one -- but crash_time_source
      # records which branch ran, so a search can separate exact times from
      # approximate ones instead of trusting all of them equally.
      - id: eval
        filter: "sourcetype === 'macos:crashreport'"
        conf:
          add:
            - name: __crash_time
              value: "Date.parse(String((/(?:\"timestamp\"\\s*:\\s*\"|Date\\/Time:\\s+)(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d+ [+-]\\d{4})/.exec(_raw) || [])[1]).replace(' ', 'T').replace(' ', ''')) / 1000"
            - name: crash_time_source
              value: "__crash_time > 0 ? 'report' : 'arrival'"
            - name: _time
              value: "__crash_time > 0 ? __crash_time : _time"
  '';
  # Host performance sampling (powermetrics, wired memory) -> index
  # mac_perf, kept out of the os event index so a sampling cadence change
  # cannot move event-telemetry volume. Same visible-sentinel rule as
  # os_events above.
  "pipelines/mac_perf/conf.yml" = ''
    output: default
    functions:
      - id: eval
        filter: "true"
        conf:
          add:
            - name: index
              value: "'mac_perf'"
            - name: sourcetype
              value: "String(__inputId).includes('powermetrics') ? 'macos:powermetrics' : String(__inputId).includes('wired_memory') ? 'macos:wiredmemory' : 'macos:unmatched'"
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
  # AI-CLI transcript pipelines, taken VERBATIM from the released pack
  # derivations (see the let block at the top) and installed as
  # worker-level pipelines. Why not run them inside the packs: on this
  # standalone Edge the pack-internal routing layer never loads — the
  # live API serves every pack a fallback `filter:true -> pipeline:main`
  # route (a pipeline none of the packs define), so events QuickConnected
  # into `pack:<id>` pass through UNPROCESSED (verified in Splunk:
  # port-stamped sourcetype, no llm.* fields). Worker-level pipelines +
  # QuickConnect are the proven path (llm_logs/firewall_logs above).
  "pipelines/codex_sessions/conf.yml" =
    builtins.readFile "${codexPack}/default/pipelines/codex_sessions/conf.yml";
  "pipelines/codex_history/conf.yml" =
    builtins.readFile "${codexPack}/default/pipelines/codex_history/conf.yml";
  "pipelines/llm_normalize/conf.yml" =
    builtins.readFile "${geminiPack}/default/pipelines/llm_normalize/conf.yml";
  # Transcript JSONL lines regularly exceed the stock 51200-byte
  # maxEventBytes (codex rollouts observed >110 KB), which silently
  # splits one JSON line into unparseable fragments. Dedicated newline
  # breaker with a 1 MiB ceiling, attached to the transcript file inputs.
  "breakers.yml" = ''
    AI CLI JSONL:
      lib: custom
      description: Newline-delimited AI-CLI transcript JSON; single lines can far exceed the 51200-byte default maxEventBytes (codex lines >1 MiB observed)
      rules:
        - condition: "true"
          type: regex
          timestampAnchorRegex: /^/
          timestamp:
            type: auto
            length: 150
          timestampTimezone: local
          timestampEarliest: -420weeks
          timestampLatest: +1week
          maxEventBytes: 4194304
          disabled: false
          eventBreakerRegex: /[\n\r]+/
          name: jsonl
      tags: ai
    # Crash/diagnostic reports run 2-3 MB per .ips body. Without this
    # they fell through to the stock `fallback` ruleset at 51200 bytes
    # and every single one was silently truncated.
    MacOS Crash Reports:
      lib: custom
      description: macOS .ips/.crash/.panic/.diag/.hang/.spin/.shutdownStall diagnostic reports; .ips bodies run 2-3 MB, far exceeding the 51200-byte default maxEventBytes that silently truncated every one of them
      rules:
        - condition: "true"
          type: regex
          timestampAnchorRegex: /^/
          timestamp:
            type: auto
            length: 150
          timestampTimezone: local
          timestampEarliest: -420weeks
          timestampLatest: +1week
          maxEventBytes: 4194304
          disabled: false
          eventBreakerRegex: /[\n\r]+/
          name: crashreport
      tags: macos,crashreport
  '';
}
