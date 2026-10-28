{
  # Session-log JSONL lines regularly exceed the stock 51200-byte
  # maxEventBytes (codex rollouts observed >110 KB), which silently
  # splits one JSON line into unparseable fragments. Dedicated newline
  # breaker with a 1 MiB ceiling, attached to the session-log file inputs.
  "breakers.yml" = ''
    AI CLI JSONL:
      lib: custom
      description: Newline-delimited AI-CLI session-log JSON; single lines can far exceed the 51200-byte default maxEventBytes (codex lines >1 MiB observed)
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
    # Each spindump summary file is one event, with a 1 MiB safety ceiling.
    WS Monitor Captures:
      lib: custom
      description: One spindump capture per event up to the maximum event size
      rules:
        - condition: "true"
          type: regex
          timestampAnchorRegex: /^/
          timestamp:
            type: current
          timestampTimezone: local
          maxEventBytes: 1048576
          disabled: false
          eventBreakerRegex: /$^/
          name: spindump
      tags: macos,ws-monitor
  '';
}
