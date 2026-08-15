# mac-studio residency budget

How `maxResidentWorkers` and `memoryHardLimitGb` are chosen for this host, and
what the limit does and does not enforce. Split out of
[mac-studio.md](./mac-studio.md) when that file reached the 12 KiB error limit
(`.file-size.yml`, which recommends splitting rather than extending the
ceiling) — this is one self-contained topic and reads better alone.

## The budget (k_max = 2 since 2026-08-05)

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

