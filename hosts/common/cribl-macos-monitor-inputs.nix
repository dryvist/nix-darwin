# macOS input fragments for standalone Edge GitOps config.
#
# These are interpolated inside the inputs.yml indented string. The splice
# site adds two spaces to its first line, so the remaining lines receive the
# same prefix here.
{ lib }:

let
  indentInputFragment =
    fragment:
    lib.removeSuffix "\n" (
      lib.concatStringsSep "\n" (
        lib.imap0 (i: l: if i == 0 || l == "" then l else "  " + l) (lib.splitString "\n" fragment)
      )
    );

  unifiedLogsRaw = ''
    # Unified Logging Subsystem, native Source.
    #
    # readMode is DELIBERATELY ABSENT. "lastEntry" is not a valid enum
    # value (the validator accepts oldest|newest only), so Cribl
    # rejected this whole input with CrudEntityInvalidError on every
    # restart -- it had never once initialized. Do not re-add it; the
    # default ("from last entry") is what was wanted anyway.
    #
    # The predicate is narrowed to the panic/thermal/jetsam path. The
    # previous one matched bare "watchdog"/"thermal" from
    # runningboardd/WallpaperAgent: 165,891 events over 3h (~1.33M/day),
    # burying the DumpPanic line that mattered. This one measured 7,901
    # over the same window (~63k/day, 21x less) and still catches it.
    # Ship it WITH the readMode fix -- readMode alone floods.
    in_macos_unified_logs:
      type: apple_unified_logs
      disabled: false
      #
      # "memory pressure" is deliberately OUTSIDE the kernel group.
      # The kernel does not use that phrasing -- every real hit is
      # userspace -- so scoping it to process == "kernel" made the
      # clause unmatchable. Measured over a 5.4h window: 73 events
      # unscoped, 0 kernel-scoped. Among the 73 is modelmanagerd
      # "Critical Memory Pressure Event Loop", from a process directly
      # implicated in memory exhaustion, which the scoped form
      # dropped. Cost of unscoping is ~73 events per 5.4h, about
      # 0.5%; the 21x narrowing survives.
      #
      # "low swap" stays kernel-scoped and matches nothing today.
      # Whether that is quiet or malformed is UNKNOWN: that the kernel
      # is the emitter of this phrasing is ASSUMED, NOT MEASURED, and
      # the identical assumption was just found wrong one clause over
      # -- "memory pressure" measured 73 unscoped against 0
      # kernel-scoped. It costs nothing today precisely because it
      # matches nothing today, so a mis-scoping would surface only
      # during swap exhaustion, which is the worst moment to find out.
      # Swap exhaustion has not occurred on this host, so there is
      # no window that tests it. The check is one measurement in a
      # window where swap actually filled; nobody has had one yet.
      #
      # UNVERIFIED, do not read as coverage: "GPU restart" and
      # "gpu hang" have never matched and there is no evidence macOS
      # emits either string. Rare and invented are indistinguishable
      # without a window containing a real GPU reset. Do not assume
      # GPU resets are handled.
      #
      # KNOWN GAP: "Metal" remains absent -- ~26% more volume for
      # streams sampled as routine chatter. SkyLight is included only
      # for the narrow hang/watchdog terms below.
      # WindowServer/SkyLight freeze & responsiveness anomalies:
      # "synchronize timed out" and WindowServer "failed to act" or
      # "Clearing datagram buffer" (replacing
      # broad log-store scans with a lightweight stall loop).
      # sudo authentication: each PAM module's verdict, the Touch ID
      # (LocalAuthentication) result, and the password fallback; plus
      # kernel library-validation rejections of third-party PAM
      # modules. Measured over 2 h: 2,031 events, 1,968 of them
      # library-validation rejections.
      # launchd and loginwindow clauses are narrow by design: launchd is limited to
      # exit, throttle and crash phrases, all kept by the unified-log pack's drop
      # filter; loginwindow to timeout and hang phrases. Volume not measured.
      # eslogger's own events are excluded here; in_macos_eslogger collects them.
      predicate: >-
        process != "eslogger" AND ((process == "kernel" AND (eventMessage CONTAINS[c] "jetsam" OR eventMessage CONTAINS[c] "memorystatus" OR eventMessage CONTAINS[c] "low swap" OR eventMessage CONTAINS[c] "panic" OR eventMessage CONTAINS[c] "IOGPU" OR eventMessage CONTAINS[c] "AGX" OR eventMessage CONTAINS[c] "thermal")) OR
        eventMessage CONTAINS[c] "memory pressure" OR process == "DumpPanic" OR process == "ReportCrash" OR
        process == "thermalmonitord" OR subsystem == "com.apple.thermalmonitord" OR
        eventMessage CONTAINS[c] "userspace watchdog timeout" OR eventMessage CONTAINS[c] "GPU restart" OR
        eventMessage CONTAINS[c] "gpu hang" OR eventMessage CONTAINS[c] "synchronize timed out" OR
        (process == "WindowServer" AND (eventMessage CONTAINS[c] "failed to act" OR eventMessage CONTAINS[c] "Clearing datagram buffer")) OR
        (process == "sudo" AND (eventMessage CONTAINS "pam_sm_authenticate" OR eventMessage CONTAINS "evaluatePolicy on" OR eventMessage CONTAINS "Authorization result" OR eventMessage CONTAINS "Error obtaining the authtok")) OR
        (process == "kernel" AND eventMessage CONTAINS "Library Validation failed") OR
        ((process == "WindowServer" OR process == "SkyLight") AND (eventMessage CONTAINS[c] "synchronize timed out" OR eventMessage CONTAINS[c] "failed to act" OR eventMessage CONTAINS[c] "hang" OR eventMessage CONTAINS[c] "watchdog")) OR
        process == "watchdogd" OR
        (process == "runningboardd" AND (eventMessage CONTAINS[c] "timed out" OR eventMessage CONTAINS[c] "timeout")) OR
        process == "spindump" OR process == "hangtracerd" OR
        (process == "kernel" AND eventMessage CONTAINS[c] "apfs" AND (eventMessage CONTAINS[c] "slow" OR eventMessage CONTAINS[c] "stall" OR eventMessage CONTAINS[c] "timeout" OR eventMessage CONTAINS[c] "took")) OR
        (process == "tccd" AND (eventMessage CONTAINS[c] "timed out" OR eventMessage CONTAINS[c] "timeout")) OR
        (process == "launchd" AND (eventMessage CONTAINS[c] "exited due to" OR eventMessage CONTAINS[c] "did not exit" OR eventMessage CONTAINS[c] "throttl" OR eventMessage CONTAINS[c] "crash")) OR
        (process == "loginwindow" AND (eventMessage CONTAINS[c] "timed out" OR eventMessage CONTAINS[c] "timeout" OR eventMessage CONTAINS[c] "hang" OR eventMessage CONTAINS[c] "watchdog")))
      sendToRoutes: false
      connections:
        - pipeline: macos_unified_logs
          output: cribl_stream
  '';

  wsMonitorRaw = ''
    # Loop timing and resource samples from the lightweight stall
    # monitor. The capture source sends one spindump summary per file.
    in_ws_monitor:
      type: file
      disabled: false
      mode: manual
      interval: 15
      path: /var/log/ws-monitor/
      filenames:
        - "*/ws-monitor.jsonl"
      recurse: false
      tailOnly: true
      sendToRoutes: false
      connections:
        - pipeline: macos_ws_monitor
          output: cribl_stream
  '';

  wsMonitorCapturesRaw = ''
    in_ws_monitor_captures:
      type: file
      disabled: false
      mode: manual
      interval: 15
      path: /var/log/ws-monitor/captures/
      filenames:
        - "*/*.summary.txt"
      recurse: false
      tailOnly: false
      sendToRoutes: false
      breakerRulesets:
        - WS Monitor Captures
      connections:
        - pipeline: macos_ws_monitor_captures
          output: cribl_stream
  '';

  # The monitor's stderr (modules/darwin/ws-monitor.nix StandardErrorPath).
  wsMonitorErrorsRaw = ''
    in_ws_monitor_errors:
      type: file
      disabled: false
      mode: manual
      interval: 15
      path: /var/log/ws-monitor/
      filenames:
        - "*/ws-monitor.err.log"
      recurse: false
      tailOnly: true
      sendToRoutes: false
      connections:
        - pipeline: macos_ws_monitor_errors
          output: cribl_stream
  '';

  # eslogger's own output (modules/darwin/eslogger.nix). The subsystem and
  # category are the defaults `eslogger --help` names for --oslog.
  esloggerRaw = ''
    in_macos_eslogger:
      type: apple_unified_logs
      disabled: false
      predicate: 'process == "eslogger" AND subsystem == "com.apple.eslogger" AND category == "events"'
      sendToRoutes: false
      connections:
        - pipeline: macos_process_lifecycle
          output: cribl_stream
  '';
in
{
  unifiedLogs = indentInputFragment unifiedLogsRaw;
  wsMonitor = indentInputFragment wsMonitorRaw;
  wsMonitorCaptures = indentInputFragment wsMonitorCapturesRaw;
  wsMonitorErrors = indentInputFragment wsMonitorErrorsRaw;
  eslogger = indentInputFragment esloggerRaw;
}
