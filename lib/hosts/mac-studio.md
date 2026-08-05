# mac-studio serving notes

Rationale for the `mlx` block in `lib/hosts/mac-studio.nix`. The module is the
code; this file is the reasoning that used to live in its comments — same split
as `modules/darwin/llm-gate.md`, done because the module reached the 12 KiB
file-size error limit (`.file-size.yml`, which recommends splitting rather than
extending the ceiling).

Serving detail that is not host-scoped lives in nix-ai's validated model catalog
(`modules/mlx/catalog-data.nix`): parser stacks, chat-template kwargs, and
per-class flag profiles. Add or fix serve args there, not here.

## Resident model selection (2026-07-27)

Promoted from the Coder-30B to the 35B for standalone operation (MacBook
unplugged, no cluster).

Every candidate was measured on this host against a dedicated isolated worker on
a scratch port, with the loaded checkpoint confirmed by
`lsof -i :PORT` → pid → `ps -p <pid>` reading `--model`. **That step is
mandatory, not ceremony**: single-model mode aliases every other model's
physical id onto the resident entry and the server echoes the requested name
back, so a model id in a request or a response proves nothing about which
weights answered.

Headline metric is cumulative tok/s — `(prompt + completion) / wall` — so
prefill gains count. Identical 111–118 token prompt, 300 `max_tokens`, 3 timed
runs after a discarded warmup, decode-concurrency 1:

| model | cumulative | decode | ttft | tools |
| --- | --- | --- | --- | --- |
| Qwen3.6-35B-A3B-4bit | **115.2** | 84.9 | 0.12s | PASS |
| Qwen3-Next-80B-A3B-Instruct-4bit | 97.5 | 71.5 | 0.08s | PASS |
| GLM-4.7-Flash-4bit | 95.8 | — | — | FAIL |
| gpt-oss-120b-MXFP4-Q8 (peer-measured) | 51–54 | 40–43 | 0.23s | FAIL |

The 35B wins on throughput outright while being the smallest of the four
(19.4 GB). GLM-4.7-Flash is disqualified on tool calls, not speed: given two
tools it emits no call at all and stops on `length`. gpt-oss-120b is
disqualified because mlx-lm ships no harmony parser, so `tool_calls` is null and
raw `<|channel|>` markup leaks into content.

Thinking is off in its catalog entry, which matters for Hermes: a thinking
variant spends hundreds of reasoning tokens before it emits a tool call, and
Hermes pays that latency on every action it takes.

## Residency budget (k_max = 2 since 2026-08-05)

The invariant, from nix-ai `modules/mlx/options-residency.nix`:

```text
maxResidentWorkers * memoryHardLimitGb <= host wired ceiling
```

The ceiling here is 100 GiB (`appleSiliconTunables.maxLocalLlmGb = 100` →
`wiredLimitMb = 102400`, in `hosts/mac-studio/default.nix`).

**At the previous k_max = 1**, the resident and the always-available 9B
collapsed into one exclusive swapping group, so loading the 9B evicted the 35B —
verified by measurement on 2026-08-05, not inferred. That was the memory bound
working as designed, not a bug, and it is why the earlier "the 9B never evicts
the resident" comment was wrong and had to be corrected (#2043).

**At k_max = 2** the tiered topology returns: a persistent resident plus a
non-exclusive small tier hold weights simultaneously. `memoryHardLimitGb` must
drop in the same change or the product over-commits the ceiling — 2 workers at
the old 99 GiB would permit 198 GiB against 100 GiB.

Chosen: `memoryHardLimitGb = 48`, so `2 × 48 = 96 GiB` with a 4 GiB cushion.
Measured working sets are 19.4 GB (35B) and ~5.2 GB (9B), leaving roughly 28 GiB
per worker above its weights for KV and the 8 GiB prompt cache.

`suppressWiredLimit` defaults true (it avoids an IOGPUFamily kernel panic), which
leaves weights pageable and makes this budget load-bearing: exceed the ceiling
and the trade is a kernel panic for swap thrash. Do not raise `maxResidentWorkers`
again without lowering `memoryHardLimitGb` to match.

`memoryHardLimitGb` is an L2 in-process cap applied by the `mlx_lm` launcher via
`mx.set_memory_limit`. It is real on this host because `modelServerBackend` is
`mlx-lm` — nix-ai `modules/mlx/assertions.nix` asserts that outright. It would
be inert under a `vllm-mlx` backend.

## Serving concurrency

`proxy.concurrencyLimit` inherits `serveConcurrency = 1`; there is no per-model
override. The 4× override this replaced was written for the Coder-30B and was
measured actively harmful on 2026-07-27: 4 concurrent streams gave 12.5 tok/s
per stream, drove gate p90 to 194 s with a 1298 s tail, returned 429 to 52% of
requests over the preceding hour, and ultimately wedged the worker outright.
Concurrency buys nothing here to offset that — `mlx_lm.server` serializes decode
internally regardless, so 4-way admission only time-slices one GPU.

This is current operating guidance while single-stream stability is established,
not a permanent ceiling. Note the 52% rejection figure above: raising
concurrency alone did **not** fix rejection rates, so it is not the lever for
them.

## Preload

`preload = [ "default" ]`. Every role alias resolves to the same 35B resident in
single-model mode, so the name is cosmetic — but it used to read `[ "goal-judge" ]`,
which reads as "warm a separate, smaller judge model" that does not exist on this
host. That misreading cost a multi-hour misdiagnosis of a warmup-starvation
incident on 2026-08-01; the actual cause was external (something kickstarting the
warmup agent in a tight loop, force-reloading the same resident). See nix-ai's
`mlx-warmup.py` re-invocation bound.

## No serving watchdog on this host

nix-ai's `launchd-watchdog.nix` gates itself on
`modelServerBackend == "vllm-mlx"`, and `assertions.nix` forces the backend to
`mlx-lm`, so the reap/kickstart/bootout recovery ladder never runs here. The
brain watchdog on the Hermes guest is the only automated recovery path for a
wedged model server.
