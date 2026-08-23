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
              value: "String(__inputId).includes('powermetrics') ? 'macos:perf:powermetrics' : String(__inputId).includes('wired_memory') ? 'macos:perf:wired_memory' : 'macos:unmatched'"
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
    # One event per crash report, timestamp taken at break time.
    #
    # The lookahead anchors on the three report-header forms and does not
    # consume them, so the header stays inside its own event and the auto
    # timestamp (length 400 -- longest observed header line is 356 bytes)
    # reads the report's own time there. Deliberately no pipeline-level _time
    # eval: two mechanisms writing _time is worse than either alone.
    #
    # maxEventBytes is load-bearing -- not because whole files were truncated
    # (under the earlier per-line breaker only one line in one sampled file
    # exceeded 51200) but because that one line IS the payload: the
    # WindowServer .ips carries 240559 bytes on a single line, cut to 21% of
    # itself at the stock ceiling. Largest artifact measured on
    # this host is 3627478 bytes; at 4 MiB that was 13% headroom, which is
    # not headroom for a class whose size tracks thread count -- the two
    # .spin samples of one event on one day differ by 14%. 16 MiB is 4.6x.
    #
    # The lookahead requires the timestamp's OPENING QUOTE, which separates a
    # report header from a report body by JSON type rather than by vocabulary:
    # a header timestamp is always a quoted date string, a body timestamp
    # always a bare epoch float. Without that one quote the pattern breaks
    # SFA-*.json*.diag into two events -- those have a compact body starting
    # at column 0, unlike a pretty-printed .ips body -- and the payload half
    # lands at break time. Verified 172/172 one break; the same pattern minus
    # the quote scores 171/172, which is the more dangerous number because it
    # does not announce itself.
    MacOS Crash Reports:
      lib: custom
      description: macOS .ips/.crash/.panic/.diag/.hang/.spin/.shutdownStall diagnostic reports; one event per report, header retained by lookahead so the auto timestamp reads the report's own time instead of Cribl arrival time
      rules:
        - condition: "true"
          type: regex
          timestampAnchorRegex: /^/
          timestamp:
            type: auto
            length: 400
          timestampTimezone: local
          timestampEarliest: -420weeks
          timestampLatest: +1week
          maxEventBytes: 16777216
          disabled: false
          eventBreakerRegex: /^(?=(?:\{[^\n]{0,119}"timestamp":"|Date\/Time:|Use spindump))/m
          name: crashreport
      tags: macos,crashreport
  '';
}
