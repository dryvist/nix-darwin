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
mandatory, not ceremony**: the server echoes the requested name back, so a
model id in a request or a response proves nothing about which weights
answered. It mattered doubly under the single-model mode this host ran until
2026-08-14, which aliased every other model's physical id onto the one
resident entry — but the response field was never evidence in either mode.

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

## Two warm brains (2026-08-14) — supersedes single-model mode

This host is the estate's **intelligence tier**; a GPU is planned to take
fast-and-small. Throughput is no longer the objective here, so both brains stay
warm and roles are split by cost rather than by preference:

| Model | Roles | Shape | Thinking |
| --- | --- | --- | --- |
| Qwen3.8-27B-4bit | default, tool-calling, most-capable, oss, coding, goal-judge | dense 27B, 64 KiB/token KV | bounded on (`reasoning_effort=low`) |
| Qwen3.6-35B-A3B-4bit | quickest, large-context | 35B MoE, ~3B active, 20 KiB/token KV | off |

`large-context` sits on the MoE deliberately: its KV costs roughly a third of
the dense model's per token.

**`singleModel` is gone, not repointed.** It aliased every role onto one entry
and demoted the rest to `disabledModels`, which is exactly what made a second
warm brain impossible. `alwaysAvailableModels` went with it — it had meaning
only in single-model mode, and its group (`swap=true, persistent=false`) could
never have held a second brain: always-available models evict each other and
idle-unload at ttl 900.

Two resident-class entries land in the `mlx-models` group, which at k_max = 2 is
`swap=false, persistent=true`, so they hold weights simultaneously. Verified
from the rendered `llama-swap-config.json`, not inferred:

```json
"mlx-models":      { "swap": false, "persistent": true,  "exclusive": true,
                     "members": ["…Qwen3.6-35B-A3B-4bit", "…Qwen3.8-27B-4bit"] }
"mlx-swap-models": { "swap": true,  "persistent": false, "exclusive": false,
                     "members": ["…Qwen3.5-9B-MLX-4bit"] }
```

Everything else is `enable = false` — **not a new restriction**. Under
`singleModel` those ids already 404'd; without it every compiled entry becomes
servable again, and a stray physical-id request would cold-load 20–63 GB beside
two residents. The 9B stays enabled because an hourly note-capture pipe requests
its exact physical id.

Measured before the switch (`vmmap`, 2026-08-14): peaks 30.9 GB (35B) + 16.6 GB
(27B) = 44.2 GiB against the 100 GiB ceiling; 28.8 / 15.5 GiB steady against the
48 GiB per-worker budget. Weights are private per-process Metal buffers —
dirty, non-volatile, no shared pages — so two workers is a straight sum, never a
discount.

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

Chosen: `memoryHardLimitGb = 48`, so `2 × 48 = 96 GiB` against a 100 GiB ceiling.

**The cushion is not 4 GiB.** 96 vs 100 ignores the non-MLX wired baseline,
measured at ~3.4 GiB host-wide while one worker decodes. Strict worst case is
`96 + 3.4 = 99.4 GiB`, so the honest cushion is **~0.6 GiB**. It still holds, and
overshoot spills to pageable memory rather than failing, but do not read 4 GiB as
spare capacity.

Per-worker budget for the resident, using measurements rather than the catalog's
declared `weightGb`:

| quantity | value | source |
| --- | --- | --- |
| weights, live RSS mid-decode | 18.72 GiB | `ps` on the running worker |
| weights, RSS recorded 2026-07-24 | 21.31 GiB | docs-starlight memory-ceilings |
| prompt cache | **16 GiB** | live `--prompt-cache-bytes 17179869184` |
| buffer cache (shedable) | up to 12 GiB | `bufferCacheLimitGb` default |

So roughly `48 − 21.3 − 16 ≈ 10.7 GiB` is left for KV and scratch — not the ~28
GiB an earlier draft of this file claimed. That draft also called 19.4 GB and
5.2 GB "measured": they are **declared** catalog `weightGb` values
(`catalog-data.nix`), they match neither disk (19.03 / 5.57 GiB) nor live RSS,
and the unit they are expressed in is undocumented. Measure W; never take it
from a spec sheet.

Note the prompt cache is 16 GiB for the **resident**, not the host-wide 8 GiB:
the resident class overrides `cacheMemoryMb = 16384` in the nix-ai catalog. The
9B runs at the host default, 8 GiB.

The worst constructible single-worker set therefore EXCEEDS 48 GiB. That is not
a defect, because `memoryHardLimitGb` refuses nothing — see below.

`suppressWiredLimit` defaults true (it avoids an IOGPUFamily kernel panic), which
leaves weights pageable and makes this budget load-bearing: exceed the ceiling
and the trade is a kernel panic for swap thrash. Do not raise `maxResidentWorkers`
again without lowering `memoryHardLimitGb` to match.

`memoryHardLimitGb` is applied by the `mlx_lm` launcher via `mx.set_memory_limit`.
It is wired up on this host because `modelServerBackend` is `mlx-lm` — nix-ai
`modules/mlx/assertions.nix` asserts that outright — and inert under `vllm-mlx`.

**It is a sizing guideline, not an enforcement.** Upstream MLX raises only when
RAM *and swap* are exhausted; crossing the limit sheds the free-buffer cache and
otherwise proceeds. So a worker can transiently exceed 48 GiB with nothing
refused, and `k_max × memoryHardLimitGb ≤ ceiling` is a budget you choose to
respect, not one the runtime imposes.

This matters for reading the numbers above: the worst constructible resident set
(~21.3 weights + 16 prompt cache + up to 12 shedable buffer cache) is larger than
48 GiB, and that is fine precisely because the limit sheds rather than fails. The
practical effect of lowering 99 → 48 is *earlier buffer-cache shedding under
long-context load*, costing some re-allocation latency — not allocation failure.

nix-ai's own prose still says this limit "forces … allocation failure ahead of
the host wired ceiling" (`options-residency.nix`, `mlx-lm-launch.py`). That
contradicts upstream semantics — failure arrives at RAM+swap exhaustion, which is
*behind* the ceiling, not ahead of it. Pre-existing defect in that repo, tracked
separately; docs-starlight already states it correctly.

## Serving concurrency (2 since 2026-08-06)

`proxy.concurrencyLimit` inherits `serveConcurrency = 2`. The host sets no
per-model override; catalog pins hold the 9B and every 40B+ entry at
`concurrencyLimit = 1` (nix-ai's 40B+ single-slot policy, flake-check
enforced), so only the resident 35B serves two-wide. Raised from 1 because a
single slot serializes every caller: with several uncoordinated callers,
queueing delay — not failure rate — dominated the latency tail. Two in-flight
requests let the server batch-decode them instead of queueing one behind the
other.

**Why 2 is safe where the 2026-07-27 4× override was harmful.** That
measurement was 4-way *admission* against a worker whose
`--decode-concurrency` was still hard-coded 1 (pre-unification): the proxy
time-sliced one serialized GPU, gave 12.5 tok/s per stream, drove gate p90 to
194 s with a 1298 s tail, returned 429 to 52% of requests, and wedged the
worker. Since the unification, admission and served width derive from one
number, and mlx-lm 0.31.3's `--decode-concurrency` feeds a real batch
scheduler (`BatchGenerator`; upstream defaults are 32 decode / 8 prompt, so 2
is conservative). The resident qwen3_5_moe is batchable in 0.31.3: no draft
model, and both cache classes its `make_cache` returns (`KVCache`,
`ArraysCache`) implement `merge`. The old note here that "`mlx_lm.server`
serializes decode internally regardless" described that hard-coded-1 state,
not 0.31.3 with the flag set. Still true: concurrency is not the lever for
*rejection* rates.

**Memory cost of the second stream.** The 35B is hybrid-attention
(config.json: 10 of 40 layers full attention, 2 KV heads, head_dim 256), so
KV costs `2 × 10 × 2 × 256 × 2 B = 20 KiB/token` — 1.25 GiB per
65,536-token stream, 5.0 GiB at the architectural max 262,144. The second
in-flight stream therefore adds ~1.3–5 GiB plus ~0.25 GiB of fixed
linear-attention state. `mlx_lm.server` trims the stored prompt cache to
`prompt-cache-bytes − active batch KV`, so stored + in-flight KV stays inside
the 16 GiB cache budget. Worst constructible worker at 2 is ~21.3 (weights) +
≤16 (KV + prompt cache) + ~0.5 (state) + ≤12 (shedable buffer cache) ≈ 50 GiB
against the 48 GiB per-worker budget — sheds cache rather than failing, and
the residency invariant is untouched: `maxResidentWorkers` counts workers,
not in-flight requests. A third request per model is parked or 429'd by
llama-swap's scheduler and never reaches the worker.

## Preload

`preload = [ "default" "quickest" ]` — two genuinely different models since
2026-08-14, where under single-model mode every role alias resolved to the same
resident and the name was cosmetic. `default` (the 27B) is listed first because
it is the slower of the two to warm. It used to read `[ "goal-judge" ]`,
which reads as "warm a separate, smaller judge model" that does not exist on this
host. That misreading cost a multi-hour misdiagnosis of a warmup-starvation
incident on 2026-08-01; the actual cause was external (something kickstarting the
warmup agent in a tight loop, force-reloading the same resident). See nix-ai's
`mlx-warmup.py` re-invocation bound.

The warmup deadline needs no adjustment for the second entry: nix-ai's
`warmup-timeout.nix` derives it as `healthCheckTimeout * len(preload) + 60`,
which is 180 × 2 + 60 = 420 s here. Restart *count* is bounded separately by
`mlx-warmup.py`, which is the actual livelock fix.

## No serving watchdog on this host

nix-ai's `launchd-watchdog.nix` gates itself on
`modelServerBackend == "vllm-mlx"`, and `assertions.nix` forces the backend to
`mlx-lm`, so the reap/kickstart/bootout recovery ladder never runs here. The
brain watchdog on the Hermes guest is the only automated recovery path for a
wedged model server.
