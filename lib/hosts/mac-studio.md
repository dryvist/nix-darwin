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

## Serving concurrency (4 since 2026-08-16)

`proxy.concurrencyLimit` inherits `serveConcurrency = 4`. No per-model
override on either resident; `qwen35-9b-mlx` keeps its own catalog
`concurrencyLimit = 1` (40B+ single-slot policy, flake-check enforced) and
does **not** inherit `serveConcurrency`, so this raise never touches the 9B.

**Why 4, measured.** The proxy's request log shows a sustained 47.5% rejection
rate at `concurrencyLimit = 2` (12,075 429s of 25,435 requests, 47.2% in the
last 500 — not a burst); accepted requests took minutes. The arithmetic below
shows the cache budget covers four streams for free, so the limit alone
turned away traffic the host could already serve.

**Why 4 is safe.** Hybrid attention only grows a KV cache
on `full_attention` layers — `linear_attention` layers carry fixed-size
recurrent state — confirmed from each model's own `config.json` on jevans-ms:

- 27B (`qwen38-27b`, `qwen3_5_text`): 64 layers, `full_attention_interval=4`
  → 16 full-attention, `kvHeads=4`, `headDim=256`. KV/token =
  `2 × 16 × 4 × 256 × 2 B = 64 KiB`.
- 35B (`qwen36-35b`, `qwen3_5_moe_text`): 40 layers → 10 full-attention,
  `kvHeads=2`, `headDim=256`. KV/token = `2 × 10 × 2 × 256 × 2 B = 20 KiB`
  (independently re-derived, matches the prior generation's figure).

Both carry `cacheMemoryMb = 16384` (16 GiB `--prompt-cache-bytes`).
`mlx_lm.server` trims stored cache to `prompt-cache-bytes − active batch KV`,
so worst case stays at 16 GiB as long as active-batch KV alone doesn't exceed
it. 27B (binding constraint): active-batch KV(N) = `N × 65536 × 64 KiB` =
**N × 4 GiB** — N=2→8, N=3→12, N=4→16 (exactly saturates the budget), N=5→20
(first overflow). **N=2/3/4 share an identical worst-case peak**:
`16.1 (weights) + 16 (cache) + ~0.3 (state) ≈ 32.4 GB`. 35B's KV(N) =
`N × 1.25 GiB`, never binding below N≈13. Raising 2→4 costs nothing extra;
N=5 is the first genuinely new territory.

**Cross-checked against measured `footprint` peaks**, all three models
loaded (9B's `concurrencyLimit=1` keeps it a fixed ~13.4 GB worst case: 5.2
weights + 8 GiB cache + ~0.15 state): 27B 34 GB observed peak (~32.4 GB
theoretical, close), 35B 30 GB observed. System-wide worst case against the
real `iogpu.wired_limit_mb=100 GiB` (one shared pool): `32.4 + 35.65 (35B) +
13.4 (9B) + 3.4 (baseline) ≈ 84.85 GB` → **~15.15 GB margin**, identical at
N=2 and N=4.

**nix-ai#915 (hybrid-attention batching crash) verified not to apply, not
just read.** The bug (`mlx_lm/models/qwen3_5.py`'s
`mx.concatenate([conv_state, qkv], ...)` throwing on a batch-size mismatch,
aborting every in-flight request) is specific to vllm-mlx's scheduler;
`modules/mlx/assertions.nix` hard-fails eval unless `mlx-lm` is the sole
backend (`docs/architecture/mlx-stack.md`). Tested directly too: the
production-pinned `mlx-lm-server` binary on a side port serving
`Qwen3.5-9B-MLX-4bit` (same `qwen3_5` family), 4 truly concurrent requests
plus a staggered-length round to force batch composition to change
mid-generation — the bug's actual trigger. Zero crashes either run.

Distinct from residency: `maxResidentWorkers` counts workers, not in-flight
requests. A fifth request per resident is parked or 429'd by llama-swap's
scheduler, never reaching the worker. (Older 0.31.3-era rejection-rate
figures, predating admission/served-width unification, are in
[mac-studio-model-history.md](./mac-studio-model-history.md).)

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

## Document OCR (Unlimited OCR)

`unlimited-ocr` is the only vision-language entry in the catalog and the only
one that is not a chat brain. It cannot run on this host's `mlx_lm.server` at
all — that server has no image input path — so the catalog pins
`backend = "mlx-vlm"` and it serves through nix-ai's mlx-vlm adapter instead.
Nothing about the other entries changes.

**Weights must already be cached on this host.** Workers run
`HF_HUB_OFFLINE=1`, so an uncached id returns 502 for minutes rather than
fetching. Note the near-miss names already on disk are different repos and do
not satisfy the catalog's id.

**`tweaks.ttl` is mandatory here, not a preference.** This host sets
`proxy.idleTtl = 0`, so there is no host-wide idle eviction, and the mlx-vlm
adapter has no worker-side idle unload of its own. Without a per-entry TTL the
weights would stay resident until the proxy restarts. 600 s sits deliberately
below the catalog's 900 s default: OCR is bursty, and a document that has been
read should give its memory back sooner than a chat model does between turns.

Swap class only, never resident — 6.7 GB of bf16 weights should not sit in the
co-residency budget between documents. The catalog also pins
`concurrencyLimit = 1`, because a full-page decode is a long single-stream job
and an over-admitting proxy turns the surplus into 429s.

## The small tier

`qwen35-9b-mlx` is the small on-demand 9B (5.2 GB) for trivial local tasks via
the Gemini-CLI path. **It stays enabled**: an hourly note-capture pipe requests
this exact physical id, and disabling it would 404 that pipe. Swap tier, so it
loads beside the residents rather than evicting one (k_max = 2).

It also carries the `small` role, on both Macs. nix-ai added that
size-class role to the AI-stack registry with no host assigning it, and
`modules/mlx/assertions.nix` requires every registry role to resolve to a
physical model AND appear in that model's compiled llama-swap aliases. So the
first `flake.lock` bump past that commit fails to evaluate until some entry
takes the role — on either Mac, since both carry a catalog.

The 9B is the size class the role names rather than an arbitrary pick, and the
router-side registry already carries the same model as `serving_role: small`.
The two agree instead of inventing a second notion of "small".
