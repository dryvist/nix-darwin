# mac-studio serving notes

Rationale for the `mlx` block in `lib/hosts/mac-studio.nix`. The module is the
code; this file is the reasoning that used to live in its comments — same split
as `modules/darwin/llm-gate.md`, done because the module reached the 12 KiB
file-size error limit (`.file-size.yml`, which recommends splitting rather than
extending the ceiling).

Serving detail that is not host-scoped lives in nix-ai's validated model catalog
(`modules/mlx/catalog-data.nix`): parser stacks, chat-template kwargs, and
per-class flag profiles. Add or fix serve args there, not here.

## Resident model selection

Superseded by "Two warm brains" below. The 2026-07-27 candidate bench that
promoted the 35B — method, the four-model throughput table, and why
GLM-4.7-Flash and gpt-oss-120b were disqualified on tool calls — is kept in
[mac-studio-model-history.md](./mac-studio-model-history.md).

One rule from it still governs every measurement on this host: confirm the
loaded checkpoint from the worker's own command line
(`lsof -i :PORT` -> pid -> `ps -p <pid>` reading `--model`). The server echoes
the requested name back, so a model id in a request or a response proves
nothing about which weights answered.

## Two warm brains (2026-08-14) — supersedes single-model mode

This host is the estate's **intelligence tier**; a GPU is planned to take
fast-and-small, so throughput is no longer the objective and both brains stay
warm. Roles split by cost, not preference:

| Model | Roles | Shape | Thinking |
| --- | --- | --- | --- |
| Qwen3.8-27B-4bit | default, tool-calling, most-capable, oss, coding | dense 27B, 64 KiB/token KV | on, `reasoning_effort=medium` |
| Qwen3.6-35B-A3B-4bit | quickest, large-context, goal-judge | 35B MoE, ~3B active, 20 KiB/token KV | off |

`large-context` sits on the MoE deliberately: its KV costs roughly a third of
the dense model's per token.

### The judge

`goal-judge` moved here from the 27B on 2026-08-15, and before that it lived on
the swap-class 9B. Three reasons, in order of what actually broke:

1. **Residency.** The 9B is swap-class at ttl=900 with a measured ~79s cold
   load. At the 2-3 goal cards/hour the fabric drains it evicted between nearly
   every card, so almost every judge call paid that in full. This entry is
   ttl=0 and cannot be evicted, so the cold load is gone rather than shortened.
2. **No self-judging.** A judge scoring its own model's output is
   self-preference bias by construction, so it cannot sit on `default`.
3. **Cost shape.** A verdict is a short, well-specified classification. The
   deliberate model's minutes buy nothing there and take the slot the real work
   wants — and the two would contend for one serving slot besides.

**Two resolvers, one name.** `goal-judge` is resolved independently by
llama-swap here and by LiteLLM in the router's registry
(`dryvist/ansible-proxmox-ai` `llm-models.yml`). Those pointed at different
models for a stretch, which is why a warmup log showing climbing cold-load
times was once read as evidence about the judge when it was about the worker.
Move both together or the ambiguity returns.

**`singleModel` is gone, not repointed.** It aliased every role onto one entry
and demoted the rest to `disabledModels` — exactly what made a second warm brain
impossible. `alwaysAvailableModels` went with it: its group is
`swap=true, persistent=false`, so those models evict each other and idle-unload
at ttl 900, and it could never have held a brain.

Two resident-class entries land in `mlx-models`, which at k_max = 2 is
`swap=false, persistent=true`, so they hold weights simultaneously. Read back
from the rendered `llama-swap-config.json`, not inferred:

```json
{
  "mlx-models":      { "swap": false, "persistent": true,
                       "members": ["…Qwen3.6-35B-A3B-4bit", "…Qwen3.8-27B-4bit"] },
  "mlx-swap-models": { "swap": true,  "persistent": false,
                       "members": ["…Qwen3.5-9B-MLX-4bit"] }
}
```

Everything else is `enable = false` — **not a new restriction**, since those
ids already 404'd under `singleModel`. Without it every compiled entry becomes
servable again and a stray physical-id request would cold-load 20–63 GB beside
two residents. The 9B stays enabled: an hourly note-capture pipe requests its
exact physical id.

Fit measured before switching (`vmmap`, 2026-08-14), not estimated: peaks
30.9 + 16.6 = 44.2 GiB against the 100 GiB ceiling; 28.8 / 15.5 GiB steady
against the 48 GiB per-worker budget. Weights are private per-process Metal
buffers with no shared pages, so two workers is a straight sum.

## Residency budget

Moved to [mac-studio-residency.md](./mac-studio-residency.md): the
`maxResidentWorkers x memoryHardLimitGb <= ceiling` invariant, the measured
per-worker figures behind 48 GiB, why the cushion is ~0.6 GiB rather than 4,
and why the limit sheds cache rather than refusing allocations.

## Serving concurrency (2 since 2026-08-06)

`proxy.concurrencyLimit` inherits `serveConcurrency = 2`. The host sets no
per-model override; catalog pins hold the 9B and every 40B+ entry at
`concurrencyLimit = 1` (nix-ai's 40B+ single-slot policy, flake-check
enforced), so only the resident 35B serves two-wide. Raised from 1 because a
single slot serializes every caller: with several uncoordinated callers,
queueing delay — not failure rate — dominated the latency tail. Two in-flight
requests let the server batch-decode them instead of queueing one behind the
other.

**Why 2 is safe where the 2026-07-27 4× override was harmful** — that
measurement predates the admission/served-width unification and ran against a
worker hard-coded to serialize decode. Figures and the batchability check for
0.31.3 are in
[mac-studio-model-history.md](./mac-studio-model-history.md). Still true:
concurrency is not the lever for *rejection* rates.

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
it is the slower of the two to warm. It used to read `[ "goal-judge" ]`, which
read as "warm a separate, smaller judge model" when no such model existed —
every role alias resolved to the same resident. That misreading cost a
multi-hour misdiagnosis of a warmup-starvation incident on 2026-08-01; the
actual cause was external (something kickstarting the warmup agent in a tight
loop, force-reloading the same resident). See nix-ai's `mlx-warmup.py`
re-invocation bound.

A separate judge model does exist now, but `goal-judge` still does not belong
in this list: it resolves to the same entry as `quickest`, so naming it would
warm nothing extra and reintroduce exactly the ambiguity above.

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
