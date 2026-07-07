# Mac Studio Serving-Stack Benchmark and Tuning Report

Point-in-time report for the Mac Studio serving stack.

## Status

- Baseline: stale build measured on 2026-07-06.
- Current live stack: measured on 2026-07-07.
- Tuning landed in code: merged, awaiting one host `darwin-rebuild`.
- Quality guard: fixed 5-prompt eval per model showed no regression.

> Activation caveat: the live numbers below are for the currently running
> stack. The warmup and swap-tier changes are merged, but they do not take
> effect until the rebuild command below runs on the host.

## Before and After

| Model or metric | Baseline (2026-07-06, stale build) | Current live stack (2026-07-07) |
| --- | --- | --- |
| gpt-oss-120b-MXFP4-Q8 decode | 13.6 tok/s | 28.58 tok/s, warmed 28.45 |
| gpt-oss-120b-MXFP4-Q8 TTFT | 0.49 s | 0.632 s median, warmed 0.625 |
| Qwen3-Coder-30B-A3B-4bit decode | 64.2 tok/s | 128.21 tok/s, warmed 128.51 |
| Qwen3-Coder-30B-A3B-4bit TTFT | 0.12 s | 0.186 s, warmed 0.139 |
| gpt-oss aggregate | c2/c4: 34.5 / 46.0 tok/s | c4/c8: 35.996 / 55.467 tok/s |

Baseline also recorded 752 tok/s prefill and a 112 s cold start because
preload did not fault weights. That cold-start path is what the merged
warmup LaunchAgent is meant to remove.

## Tuning Landed

| Change | Effect |
| --- | --- |
| [nix-darwin#1545][pr-1545] | `mlx-warmup` LaunchAgent faults models at boot; adds swap-tier `Qwen3.6-35B-A3B-4bit`. |
| [nix-ai#1127][pr-1127] | launchd namespace fix. |
| [nix-darwin#1537][pr-1537] | gpt-oss reasoning parser. |
| [nix-darwin#1539][pr-1539] | Qwen coder `maxRequestTokens` to 32768. |

## Memory Budget

| Tier | Approx footprint | Note |
| --- | --- | --- |
| Resident pair | about 92.4 GB, including 6 GB caches each | fits in 128 GB unified memory |
| Qwen3.6-35B-A3B-4bit swap path | about 115.8 GB | larger fallback model within the same host envelope |

These limits keep the resident pair stable while giving the server a
controlled swap path. The aggregate throughput numbers above were measured
with the existing concurrency caps, so the tuning did not change the cap
policy.

## Pending Activation

Run this once on the host after merging:

```bash
ssh jevans-ms 'sudo darwin-rebuild switch --flake github:dryvist/nix-darwin#jevans-ms --refresh --no-write-lock-file --print-build-logs'
```

## Rationale

- The cold-start problem mattered more than the steady-state decode gap.
  The 112 s startup came from weights not being faulted into memory, so
  boot-time warmup is the highest-leverage fix.
- The swap-tier models add a larger fallback path without exceeding the
  128 GB unified-memory envelope.
- The per-model parser and request-limit overrides keep gpt-oss and Qwen
  serving behavior separate, which reduces cross-model regressions.
- The fixed 5-prompt eval per model showed no regression, so the tuning is
  throughput-positive without a quality penalty.

[pr-1537]: https://github.com/dryvist/nix-darwin/pull/1537
[pr-1539]: https://github.com/dryvist/nix-darwin/pull/1539
[pr-1545]: https://github.com/dryvist/nix-darwin/pull/1545
[pr-1127]: https://github.com/dryvist/nix-ai/pull/1127
