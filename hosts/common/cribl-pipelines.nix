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
  # in_cluster_logs (rank and lifecycle decisions) shares this same
  # pipeline but is a third, unrelated event shape — discriminate on
  # __inputId FIRST (same pattern as os_events below) to keep its lines
  # from falling through the content regex and landing mislabeled as
  # mlx:model-server output.
  #
  # None of the three source formats carries a timestamp Cribl can
  # reliably parse at the line start (llama-swap's own `[INFO] Request
  # ...` access lines and the cluster lifecycle lines have no leading
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
  # system_metrics -> index=llm (EVENT), sourcetype mlx:metrics. The
  # workstation_load branch extracts node_load5 separately. The judge Process
  # Set adds its start-time metric fields here; Stream republishes that signal
  # and workstation_load's node_load5 as native metrics for the metric sinks.
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
      - id: eval
        filter: "process_start_time_seconds !== undefined"
        conf:
          add:
            - name: _metric
              value: "'judge_process_start_time_seconds'"
            - name: _value
              value: "Number(process_start_time_seconds)"
  '';
  # Send only the workstation's native five-minute load gauge through the
  # existing Stream metric fan-out. TCP JSON preserves these ordinary fields;
  # Stream recreates the Cribl metric before forwarding to the metric sinks.
  "pipelines/workstation_load/conf.yml" = ''
    output: default
    functions:
      - id: drop
        filter: "!Number.isFinite(Number(node_load5))"
      - id: eval
        filter: "true"
        conf:
          add:
            - name: _metric
              value: "'node_load5'"
            - name: _value
              value: "Number(node_load5)"
            - name: host_role
              value: "'workstation'"
            - name: index
              value: "'llm'"
            - name: sourcetype
              value: "'mlx:metrics'"
          remove: [node_load5]
  '';
  # Critical macOS event telemetry -> index=os. sourcetype is derived from
  # __inputId, one explicit branch per wired Source. The fallback is a visible
  # sentinel and NOT a real sourcetype: an unguarded chain used to relabel
  # anything unmatched as unified-log data, so a mis-wired Source looked
  # correct in Splunk. An unmatched event now shows up as unmatched.
  #
  # Names are the cc-edge-the-mac-pack-io namespaced set, not the flat ones
  # this host shipped before. The Splunk TA keys its props to the namespaced
  # names and two published pack releases announced them as breaking, so the
  # flat names were arriving under a name no props matched. Do not flatten.
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
              value: "String(__inputId).includes('unified_logs') ? 'macos:unified_log' : String(__inputId).includes('crashreports') ? 'macos:crashreport' : String(__inputId).includes('thermal') ? 'macos:system:thermal' : 'macos:unmatched'"
      # Does THIS event carry a report timestamp of its own? Deliberately not
      # named for provenance: the breaker writes _time, and this pipeline
      # cannot see whether the breaker's auto-timestamp actually parsed, so a
      # name asserting where _time came from would claim knowledge that is not
      # available here. This is a content test on the bytes in front of it,
      # true regardless of what the breaker did.
      #
      # A positive test, with the failure falling out rather than being
      # special-cased: anything that is neither a quoted-JSON-timestamp header
      # nor a Date/Time: line reads false. That is exactly .shutdownStall, a
      # base64 spindump with no in-band time. Regex taken verbatim from the
      # pack so two hand-written equivalents cannot drift apart; only the
      # filter differs, because this instance has no datatype field and keys
      # on sourcetype instead.
      - id: eval
        filter: "sourcetype === 'macos:crashreport'"
        conf:
          add:
            - name: crash_time_in_band
              value: "/^(?:\\{[^\\n]{0,119}\"timestamp\":\"|Date\\/Time:)/.test(_raw)"
  '';
  # Host performance sampling (powermetrics, wired memory, ws-monitor) -> index
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
              value: "String(__inputId).includes('ws_monitor_captures') ? 'ws-monitor:spindump' : String(__inputId).includes('ws_monitor') ? 'ws-monitor' : String(__inputId).includes('powermetrics') ? 'macos:perf:powermetrics' : String(__inputId).includes('wired_memory') ? 'macos:perf:wired_memory' : 'macos:unmatched'"
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
  "pipelines/workstation_offload/conf.yml" = ''
    output: default
    functions:
      - id: eval
        filter: "true"
        conf:
          add:
            - name: index
              value: "'workstation'"
            - name: sourcetype
              value: "'macos:offbox_sync'"
  '';
  "pipelines/workstation_jobs/conf.yml" = ''
    output: default
    functions:
      - id: eval
        filter: "true"
        conf:
          add:
            - name: index
              value: "'workstation'"
            - name: sourcetype
              value: "'macos:local_job'"
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
  "pipelines/claude_sessions/conf.yml" = builtins.readFile ./cribl-claude-sessions.conf.yml;
  "pipelines/codex_history/conf.yml" =
    builtins.readFile "${codexPack}/default/pipelines/codex_history/conf.yml";
  "pipelines/llm_normalize/conf.yml" =
    builtins.readFile "${geminiPack}/default/pipelines/llm_normalize/conf.yml";
}
