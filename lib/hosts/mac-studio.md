# mac-studio serving notes

Notes for the `mlx` block in `lib/hosts/mac-studio.nix`. The module is the
code; this file holds the reasoning that does not fit in its comments (the
module sits at the file-size budget in `.file-size.yml`).

Serving detail that is not host-scoped lives in nix-ai's validated model catalog
(`modules/mlx/catalog-data.nix`): parser stacks, chat-template kwargs, and
per-class flag profiles. Add or fix serve args there, not here.

## Resident model selection

Catalog selection, preload roles, per-model concurrency and the
resident-worker count are projected from the role map for this host's class
(`lib/role-map-host.nix`, applied by `hosts/common/role-map.nix`). The host
file states only runtime posture. The previous model selections and the bench
that chose them are kept in
[mac-studio-model-history.md](./mac-studio-model-history.md).

One rule still governs every measurement on this host: confirm the loaded
checkpoint from the worker's own command line
(`lsof -i :PORT` -> pid -> `ps -p <pid>` reading `--model`). The server echoes
the requested name back, so a model id in a request or a response proves
nothing about which weights answered.

## Classes and roles

The `server` class keeps two resident workers and one swap model:

| Model | Class | Concurrency | Roles |
| --- | --- | --- | --- |
| Qwen3.8-27B-4bit | resident | 1 (dense) | best, default, coding, long |
| MiMo-9B-OptiQ-4bit | resident | 2 | fast, cheap, small, judge, recorder |
| Unlimited-OCR | swap | 1 | ocr |

Only this class holds the OCR swap. The registry (`services.aiStack.models`)
carries exactly the roles the map assigns to the class, so the eval-time
assertion that every registry role compiles into a llama-swap alias is checked
against what the class declares.

Two resident-class entries land in `mlx-models`, which at k_max = 2 is
`swap=false, persistent=true`, so both hold weights simultaneously. The OCR
model lands in `mlx-swap-models` (`swap=true, persistent=false`).

## Residency budget

See [mac-studio-residency.md](./mac-studio-residency.md): the
`maxResidentWorkers x memoryHardLimitGb <= ceiling` invariant, why the cushion
is ~0.6 GiB rather than 4, and why the limit sheds cache rather than refusing
allocations. `memoryHardLimitGb` derives from the ceiling and the resident
count; nothing sets it by hand.

## Serving concurrency

`proxy.concurrencyLimit` is `serveConcurrency = 2`, the admission ceiling. Each
model's own limit comes from the role map. A 2026-08-16 raise of the proxy
ceiling to 4 was reverted the same day: MLX batches concurrent sequences on
shared GPU compute, so on a compute-bound dense model more slots stretch latency
instead of adding throughput. Memory was never the binding constraint.

Hybrid attention only grows a KV cache on `full_attention` layers; the dense 27B
(64 layers, `full_attention_interval=4`, `kvHeads=4`, `headDim=256`) costs
`2 x 16 x 4 x 256 x 2 B = 64 KiB` per token.

`maxResidentWorkers` counts workers, not in-flight requests. A request beyond a
model's concurrency is parked or 429'd by llama-swap's scheduler, never reaching
the worker.

## Preload

`preload` names one role per resident model, derived from the map. A preload
entry must name a role, not a model that reads as one: a role alias that
resolves to an unintended model once cost a multi-hour misdiagnosis of a
warmup-starvation incident (the actual cause was something kickstarting the
warmup agent in a tight loop). See nix-ai's `mlx-warmup.py` re-invocation bound.

The warmup deadline needs no adjustment per entry: nix-ai's `warmup-timeout.nix`
derives it as `healthCheckTimeout * len(preload) + 60`.

## No serving watchdog on this host

nix-ai's `launchd-watchdog.nix` has no serving backend to supervise on this
host, so the reap/kickstart/bootout recovery ladder never runs here. The brain
watchdog on the Hermes guest is the only automated recovery path for a wedged
model server.

## Document OCR (Unlimited OCR)

`unlimited-ocr` is the only vision-language entry in the catalog and the only
one that is not a chat brain. It cannot run on `mlx_lm.server` (no image input
path), so the catalog pins `backend = "mlx-vlm"` and it serves through nix-ai's
mlx-vlm adapter.

**Weights must already be cached on this host.** Workers run
`HF_HUB_OFFLINE=1`, so an uncached id returns 502 for minutes rather than
fetching.

**`tweaks.ttl` is mandatory here.** This host sets `proxy.idleTtl = 0`, so there
is no host-wide idle eviction, and the mlx-vlm adapter has no worker-side idle
unload of its own. Without a per-entry TTL the weights would stay resident until
the proxy restarts. 600 s sits below the catalog's 900 s default: OCR is bursty,
and a document that has been read should give its memory back sooner.

Swap class only, never resident, and `concurrencyLimit = 1` in the catalog,
because a full-page decode is a long single-stream job.
