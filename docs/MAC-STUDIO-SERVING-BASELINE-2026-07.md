# Mac Studio (jevans-ms) LLM Serving Baseline — 2026-07-06/07

Baseline + tuning-pass findings for the always-on local inference server
(`hosts/mac-studio/`), captured before/around landing
[#1537](https://github.com/dryvist/nix-darwin/pull/1537) and
[#1539](https://github.com/dryvist/nix-darwin/pull/1539). This is a snapshot,
not a living doc — treat numbers as one measurement, not a guarantee.

## Config as committed vs. as deployed

Two PRs merged into `main` on 2026-07-07 but were **not yet deployed** to
jevans-ms at benchmark time (`darwin-rebuild switch` needs an interactive
sudo password — this document does not attempt it; see "Parked steps" below):

| PR | What it does | Committed | Live on host (verified via `ps` over SSH) |
| --- | --- | --- | --- |
| [#1537](https://github.com/dryvist/nix-darwin/pull/1537) | `--reasoning-parser gpt_oss` on gpt-oss-120b | Yes | **No** — flag absent |
| [#1539](https://github.com/dryvist/nix-darwin/pull/1539) | `maxRequestTokens` 32768 for Qwen3-Coder only | Yes | **No** — still 8192 |

Companion PR [`ansible-proxmox-apps#658`](https://github.com/dryvist/ansible-proxmox-apps/pull/658)
(hermes-agent `max_tokens` clamp fix + router repoint from the dead
`llm-large.<domain>` alias to `jevans-ms.<domain>` directly) is merged **and**
converged live.

## Serving registry (current, `lib/hosts.nix`)

Only two models are configured for jevans-ms — no others are in the registry:

| Role | Model | Size | Tool parser | Notes |
| --- | --- | --- | --- | --- |
| `default` | `mlx-community/gpt-oss-120b-MXFP4-Q8` | 63.3 GB | `harmony` | Paged KV cache + prefix caching off (vllm-mlx 0.4.0 conflict) |
| `coding` | `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` | 17.1 GB | `qwen3_coder` | Prefix caching + paged cache on |

Shared sizing: `cacheMemoryMb=12288` per worker, `prefillBatchSize=4096`,
`maxNumSeqs=4` (nix-ai default), `idleTtl=0` / `autoUnloadIdleSeconds=0` (no
eviction), `groupSwap=false` (both stay resident — no swap-thrash between
them), `preload=[default, coding]`, proxy `concurrencyLimit=8`.

Combined weights ≈ 80.4 GB + 2×12 GB cache ≈ 105 GB against the 118 GB wired
ceiling — roughly 13 GB of headroom for the proxy/framework.

## Hardware envelope

Apple M4 Max, 16 cores (12P+4E), 128 GB unified memory, macOS 26.5.2.
Uptime at benchmark time: 2d 8h55m, load average ~0.65/16 — idle outside the
benchmark run. No thermal or performance warnings recorded.

## Benchmark results

All requests: `temperature=0`, `/v1/chat/completions`, plain chat (no harmony
wrapping needed at the API layer). Decode = 512-token-target essay prompt;
prefill = large filler prompt; concurrency = N parallel 256-max-token
completions. Run against the live gate via `curl --resolve` (see "DNS gap"
below) with a bearer token sourced live from Doppler.

| Model | cold-start (s) | TTFT (s) | decode tok/s (c1) | prefill tok/s (@ tokens) | c2 agg tok/s | c4 agg tok/s | c8 agg tok/s |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Qwen3-Coder-30B-A3B-4bit | 0.45† | 0.12 | 64.2 | 799.2 (@ 22,773) | 164.7 | **222.3** | 130.5 |
| gpt-oss-120b-MXFP4-Q8 | 111.76 | 0.49 | 13.6 | 752.7 (@ 22,832) | 34.5 | **46.0** | 36.9 |

† Qwen coder had been restarted shortly before this run, so its cold-start
number reflects a recent restart, not a multi-day-idle load. See "Cold-start
finding" below for the gpt-oss number, which is the meaningful one.

Long-context probe (large filler prompt, `max_tokens=8`): both models
returned 200 successfully at ~57k prompt tokens (Qwen: 56,921 tokens, 2.16s —
almost certainly a prefix-cache hit against the immediately-preceding prefill
probe's near-identical filler text, not a true cold long-context timing;
gpt-oss: 56,980 tokens, 69.27s, consistent with its measured prefill rate).

### Concurrency finding: both models peak at c4, regress at c8

Aggregate throughput peaks at concurrency=4 for both models and **drops** at
concurrency=8 (Qwen: 222.3→130.5 tok/s, −41%; gpt-oss: 46.0→36.9 tok/s,
−20%). This lines up exactly with `maxNumSeqs=4` — the vllm-mlx worker only
truly batches 4 sequences; the proxy's `concurrencyLimit=8` lets 4 more
requests queue behind that batch rather than round-robining more efficiently.

Every c8 request still completed with `200` (no failures) — so the current
`concurrencyLimit=8` is honoring its documented intent ("agents and the web
UI burst-tolerate instead of hard-failing" per the `lib/hosts.nix` comment)
rather than being a bug. It's a genuine tradeoff, not a defect:

- **Keep `concurrencyLimit=8`** if burst-tolerance (never 429, accept slower
  aggregate throughput under sustained 5-8 concurrent load) matters more than
  peak throughput.
- **Lower it to 4** (matching `maxNumSeqs`) if peak aggregate throughput
  matters more and a hard 429 beyond 4 concurrent requests is acceptable.
- **Raise `maxNumSeqs`** (if cache memory allows — needs live headroom
  testing post-deploy) to let the worker itself batch more true concurrent
  sequences, which would let `concurrencyLimit=8` actually pay off.

No config change made for this — it's a product decision, not a bug fix.

### Cold-start finding: gpt-oss's 112s load is one-time, not a keep-warm failure

The 111.76s gpt-oss cold-start looked, at first, like a `preload`/`idleTtl=0`
failure (uptime was 2d 8h55m at the time, and the process's RSS was only
~165 MB — nowhere near its 63 GB of weights). But a follow-up
warm-characterization test run immediately after a concurrency=8 stress test
against gpt-oss showed three consecutive requests at 0.47s, 1.19s, 1.25s —
fully warm.

This means: once a **real inference request** actually touches the model,
it stays resident (confirming `idleTtl=0` / `autoUnloadIdleSeconds=0` work as
intended). The gap is that `hooks.on_startup.preload` (llama-swap's startup
hook, `modules/mlx/default.nix:252`) evidently does **not** force the
underlying vllm-mlx worker to eagerly materialize weights into memory/GPU
buffers — only a real inference call does that. So "preload" currently
means "have the process ready to accept a request," not "have the weights
actually loaded" — the first real request after any period where gpt-oss
was never touched (which, given it isn't the `default`-role model for every
consumer, could be common) pays close to the full ~60-120s load cost the
`lib/hosts.nix` comments already anticipated.

**Recommendation**: don't touch `idleTtl`/`autoUnloadIdleSeconds` (they're
working correctly) — instead, either confirm whether llama-swap's preload
hook has a "send a real request" mode, or add an explicit synthetic warmup
request (e.g., a 1-token completion) right after the `vllm-mlx`/`llama-swap`
LaunchAgents come up, so the boot-time preload actually means what it says.
Not attempted here — needs on-box verification of llama-swap's preload
semantics before writing a fix.

### "Raise max context to 262144" — not a flag, and not free

`vllm-mlx serve --help` (0.4.0, the pinned version) has **no** `--max-model-len`
/ `--context-length` flag. Context length is governed automatically by the
model's own rope-scaled native maximum (Qwen3-Coder-30B-A3B: 262144 native;
gpt-oss-120b: 131072 native) — nothing needs to be raised to "enable" it, and
our long-context probe already exercised ~57k tokens successfully on both.

The actual constraint is KV cache memory. `--max-kv-size` exists but *bounds*
context (rotates out early tokens once exceeded — the opposite of what's
wanted) and is explicitly banned from proxy-level args by this repo's own
`lib/checks/mlx.nix` (it belongs in a per-model `modelExtraArgs` override if
ever used, not the shared proxy config). Rough KV-cache math for a
transformer-family model at a **single** 262144-token sequence, fp16
K+V (`2 × layers × kv_heads × head_dim × seq_len × 2 bytes × 2 (K and V)`),
lands in the tens-of-GB range per sequence — comfortably exceeding the
current 12 GB `cacheMemoryMb` reservation per worker, before any
concurrency or the second resident model is even considered.

**Recommendation**: if genuinely huge single-request contexts are a real
requirement (not just "the model supports it"), the concrete lever is
`--kv-cache-quantization` (`--kv-cache-quantization-bits 4` or `8`), which
shrinks the KV cache 2-4x — but this needs real on-box measurement (does
quality hold up at 4-bit KV, does it actually fit alongside both resident
models) that requires the parked `darwin-rebuild` step first. Not applied
here.

## DNS gap (found, not fixed)

`jevans-ms.<domain>` returns `NXDOMAIN` from the internal DNS server — no
split-horizon A record exists; only mDNS/Bonjour resolves the bare
`jevans-ms` hostname on the same L2 segment. All benchmarks in this doc were
run via `curl --resolve` (forcing the mDNS-resolved IP while keeping correct
SNI/Host) to work around this. `ansible-proxmox-apps#658`'s router repoint
to `jevans-ms.<domain>` depends on this resolving from the hermes-agent LXC's
network path — worth confirming separately since the resolver failure mode
observed here (NXDOMAIN from the internal gateway, not a timeout) would
break that repoint identically if the LXC uses the same resolver.

## Branch cleanup (owned as part of this pass)

Four in-flight AI-related `nix-darwin` branches were triaged to avoid
conflicting with this tuning work:

| Branch | Verdict |
| --- | --- |
| `fix/gptoss-harmony-reasoning-leak` | Merged (#1537) — worktree + local branch removed |
| `fix-mac-studio-qwen-coder-output-cap` | Merged (#1539) — worktree + local branch removed |
| `feature/dynamic-local-ai-model` (nix-darwin) | Closed [#1542](https://github.com/dryvist/nix-darwin/pull/1542) — model not in registry |
| `feat/macos-llm-perf-tunables` | Open [#1541](https://github.com/dryvist/nix-darwin/pull/1541) — stale; naive rebase risk noted on PR |

The companion cross-repo branch `feature/dynamic-local-ai-model` in
`ai-assistant-instructions` ([#716](https://github.com/dryvist/ai-assistant-instructions/pull/716))
was also assessed: it's independently valuable (replaces every hardcoded
model name in `AGENTS.md`/`select-model.sh` with a "discover live, use
`$AI_MODEL_LOCAL` as an optional hint" pattern) and doesn't depend on the
closed nix-darwin PR's specific model value. Left open with a comment
identifying the one obsolete hunk (a `agentsmd/permissions/ask/security.json`
edit — that file no longer exists on `main`, the whole permissions tree
having migrated to `nix-claude-code`).

## Parked steps (need a human)

- **`darwin-rebuild switch` on jevans-ms** — needs an interactive sudo
  password; not attempted from this session. Until this runs, PRs #1537 and
  #1539 have no effect in production despite being merged.
- **KV-cache-quantization experiment** (if huge single-request contexts are
  actually needed) — needs the above rebuild plus live memory-headroom
  testing.
- **Concurrency-limit decision** (keep 8 for burst tolerance vs. lower to 4
  for peak throughput vs. raise `maxNumSeqs`) — a product tradeoff for
  whoever owns this host's SLA, not something to silently change.

## Reproducing this benchmark

Bearer token: Doppler project `iac-conf-mgmt`, config `prd`, secret
`LLM_LARGE_BEARER_TOKEN`. Gate: `https://jevans-ms.<domain>:11434` (use
`curl --resolve` against the mDNS-resolved IP until the DNS gap above is
fixed). See `/v1/models` for what's currently being served before assuming
this doc's model list is still current — it changes.
