# PR 3236 review verdict

Reviewed head: 991f0a1430715ba7c481a6b934fc486eeaa15a8a (`fix/pf-loader-flush-first`, base `develop` f2c48f64).

Abbreviations: script `modules/darwin/scripts/pf-hardening-load.sh`; tests `tests/shell/test_pf_hardening_load.bats`;
module `modules/darwin/pf-hardening.nix`; flake `flake.nix`.

Tooling: shellcheck 0.11.0 run on the script with the `writeShellApplication` shebang prepended: clean at default and
style severity. `bats` is not installed in this sandbox and the nix/tarball fetches to obtain it are blocked (403),
so bats itself was NOT run; the suite was executed under a bash shim reproducing bats `run` and `errexit` semantics:
10/10 pass against the PR loader, the develop suite passes 9/9 against the develop loader, and the new suite fails
exactly its tests 1-4 against the develop loader, matching the PR body's claim.

1. CONFIRMED — flush s37, verify s38, load s39, enable s42, info s43; flush-fail exits s38 pre-load; load-fail s40 pre-enable; enable-fail s44; names m:81-82
2. CONFIRMED — load-fail: off, enforcing name flushed s37-38 pre-load; on: it stays unfilled (pfctl parses whole file; flake:519); flush-fail exits pre-load.
3. CONFIRMED — FAILED:<step> via s15-18 at s38/s40/s44; stderr in log s37/s39/s42; exit 1; m:197 relaunches failures only; m:198 throttle 30 s; DNS only s39.
4. CONFIRMED — `set -euo pipefail` s11; env guard s12; expansions quoted, split only s30; pipelines explicit s24/s30/s37/s39/s42; no traps; shellcheck clean.
5. CONFIRMED — t32/44/55/66 fail on develop, 10/10 on PR; absence = run grep + status t71/t90; negatives: load t44/t55, flush t66/81/87, enable t101.
6. CONFIRMED — the diff lists only the script and tests; rule generation m:32-67 and the rule-order check flake:487-526 (orderChecks 505-517) are untouched.
7. CONFIRMED — commit and PR text state the behavior; greps for estate hosts and IPv4: no hits; unresolvable-name example hypothetical; no failure narrative.

Findings:

- script:39 — with `pipefail`, a tee/logger failure inside the process substitution judges the load failed while pfctl
  committed the rules. Sequence: pfctl exits 0 -> logger dies -> tee hits EPIPE -> pipeline non-zero -> `fail "load ...
  NOT active"` and exit 1 while the anchor IS active; launchd (module:197-198) retries every 30 s and the retry
  converges to a clean success. Wrong outcome: one misleading log line plus one redundant retry. Requires /usr/bin/logger
  to fail, outside the reviewed failure directions. Pre-existing on develop, unchanged by this PR. Severity: low.

- script:24,30 — the `flushed()` probes send stderr to /dev/null, so the log names the failed step (`FAILED: flush
  <anchor>` via :38) but not which probe ruled the flush failed (rules listing vs anchor still listed). Severity:
  informational.

- tests:111 — the one remaining negation is a bracket assertion (`[ ! -s ]`), which fails a bats test properly; no bare
  `! cmd` remains anywhere in the suite. Severity: informational.

- tests:66 — the flush-failure negative case runs only under the enforce-on name mapping; the flush-then-load order is
  name-independent, and the load-failure direction has both mappings (:44, :55). Severity: informational.

Tooling summary: bats NOT RUN (binary unavailable; suite verified via the shim described above); shellcheck RUN, clean.

VERDICT: MERGE
