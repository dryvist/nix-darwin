# macOS Performance Tuning for Local LLM Inference

Exhaustive reference for every macOS / hardware-layer knob that can affect local LLM inference on
this machine — **Apple Silicon M4 Max MacBook Pro, 128 GB unified memory, macOS Tahoe 26.x**
(frameworks: MLX / mlx_lm, llama.cpp, LM Studio).

Every parameter is recorded here even when left at its macOS default, so the OS surface is fully
documented. Knobs that this repo wires declaratively link to their nix option; knobs that cannot be
set from nix (or belong to the LLM-software layer) are marked accordingly.

## Scope boundary

This repo (`nix-darwin`) owns the **OS / launchd layer**: `sysctl`, `pmset`, `launchd`
daemons/agents (incl. environment), `defaults`, filesystem. The **LLM-software layer** — MLX
process-level memory limits, KV-cache bounds, llama.cpp runtime flags — is tuned separately
and is listed under [Owned by the LLM-software layer](MACOS-LLM-PERFORMANCE-TUNING-PT2.md#owned-by-the-llm-software-layer-not-os-config)
for completeness only.

## Persistence legend

- **VOLATILE** — resets on reboot; re-applied via a `RunAtLoad` launchd daemon (and at activation).
- **PERSIST** — survives reboot once written (pmset plist / `defaults` domain / filesystem).
- **VERIFY** — cannot be set programmatically; activation only audits and warns.
- **SCOPE** — applies to the launchd/process environment, not system-wide.

## nix option → module map

| Option | Module |
| --- | --- |
| `system.appleSiliconTunables.*` | `modules/darwin/apple-silicon-tunables.nix` |
| `system.resourceLimits.*` | `modules/darwin/system-limits.nix` |
| `system.networkTuning.*` | `modules/darwin/network-tuning.nix` |
| `system.energy.*` | `modules/darwin/energy.nix` (sleep/wake timer policy) |

Volatile sysctls are applied by `scripts/apple-silicon-sysctls.sh`, `scripts/system-limits.sh`, and
`scripts/network-tuning.sh`; the persistent/verify knobs by `scripts/apple-silicon-tunables.sh`.

---

## Category 1 — Unified memory / GPU wired limit

The single highest-impact knob. Apple Silicon shares one unified-memory pool; macOS caps how much
the GPU/Metal can wire (pin resident). Raising it keeps larger models + KV cache GPU-resident.

| Parameter | nix option / cmd | Default | This host | Persist | Notes |
| --- | --- | --- | --- | --- | --- |
| `iogpu.wired_limit_mb` | `wiredLimitMb` | ~75% RAM (128 GB → ~96 GB) | `118000` (~115 GB) | VOLATILE | #1 knob; `0` = use default |
| `iogpu.wired_lwm_mb` | `wiredLwmMb` | macOS default | `null` (leave) | VOLATILE | no source recommends changing |
| `vm.compressor_mode` | `vmCompressorMode` | `4` (compress + swap) | `null` (leave `4`) | reboot | mode 2 risks hard-OOM |

Formula: `desired_MB = (total_GB − headroom_GB) × 1024`, leaving 8–16 GB. `118000` leaves ~13 GB.
`sysctl iogpu.wired_limit_mb` reads it; `0` means "use the 75% default". MLX wires memory itself and
**bypasses Jetsam/memory-pressure**, so an unbounded KV cache can kernel-panic the machine — the
sysctl cap does not protect against that (see the LLM-software layer).

## Category 2 — Power / pmset

High Power Mode is the biggest sustained-throughput lever on a laptop (raises the fan ceiling,
defers thermal throttling), but there is **no `pmset`/`sysctl`/`defaults` key** for it.

| Parameter | nix option / cmd | Default | This host | Persist | Notes |
| --- | --- | --- | --- | --- | --- |
| Energy Mode (High Power) | `energyMode` (verify) | Automatic | `"high"` | VERIFY | manual: System Settings → Battery |
| `pmset -a lowpowermode` | `pmset.lowPowerMode` | `0` | `false` (0) | PERSIST | LPM caps performance — keep off |
| `pmset -a powernap` | `pmset.powerNap` | `1` | `false` (0) | PERSIST | avoids background wakes |
| `pmset -a proximitywake` | `pmset.proximityWake` | `1` | `false` (0) | PERSIST | fewer spurious wakes |
| `pmset -a disablesleep` | `pmset.disableSleep` | `0` | `null` (leave) | PERSIST | sledgehammer; `sleep.ac=0` covers AC |
| `pmset -a tcpkeepalive` | `pmset.tcpKeepAlive` | `1` | `null` (leave) | PERSIST | only for serving in standby |
| sleep / displaysleep / disksleep | `system.energy.*` | — | ac=0, batt=60, disp=30, disk=10 | PERSIST | sleep-timer policy (separate module) |

`energyMode` drives a verify/nudge: activation reads `pmset -g custom`, parses the AC-block
`powermode` (observed: 0 = Automatic, 1 = High Power, 2 = Low Power) and logs a WARN on drift.
Set it once: **System Settings → Battery → Energy Mode → High Power** (M4 Max is supported), or via an
MDM Energy Saver profile. `gpuswitch` is meaningless on Apple Silicon (single GPU).

## Category 3 — Thermal / sustained performance

Observe-only — there is no nix knob; High Power Mode (Category 2) and cooling are the levers.

| Concern | Tool / action | Notes |
| --- | --- | --- |
| Throttle monitoring | `sudo powermetrics --samplers cpu_power,gpu_power,thermal` | thermal-pressure: Nominal → Critical |
| GUI monitor | `mactop` (installed) | real-time CPU/GPU/ANE/thermal |
| Mitigation | High Power Mode + active cooling + cool ambient | M4 Max laptop throttles ~5 min into sustained 70B |

The same M4 Max in a Mac Studio holds peak for hours — the laptop limiter is heat dissipation, not
the chip. Expect a ~15–20% sustained haircut on the laptop after the first several minutes.

## Category 4 — CPU scheduling / App Nap

macOS schedules by QoS class, not manual core pinning. A low-QoS / App-Napped process is confined to
E-cores (much slower).

| Parameter | nix option / cmd | Default | This host | Persist | Notes |
| --- | --- | --- | --- | --- | --- |
| App Nap disabled for | `appNapDisabledFor` | App Nap on | `[dev.mlx-model-server]` | PERSIST | per-app `NSAppSleepDisabled` |
| `taskpolicy -B` | (doc-only) | — | — | SCOPE | cannot reliably promote to P-cores |
| thread count `-t` | (LLM-software layer) | — | — | — | M4 Max = 12 P + 4 E; `-t 12` common |

`taskpolicy -B` can demote to E-cores but cannot promote a thread already at low QoS (authoritative:
Eclectic Light). The reliable path is keeping inference foregrounded at normal/high QoS with App Nap
disabled.

## Category 5 — Memory pressure / VM / swap

| Parameter | nix option / cmd | Default | This host | Persist | Notes |
| --- | --- | --- | --- | --- | --- |
| `vm.compressor_mode` | `vmCompressorMode` (Cat 1) | `4` | `null` (leave) | reboot | disabling swap risks hard-OOM |
| `vm.swapusage` | `sysctl vm.swapusage` (read) | — | — | — | diagnose pressure |
| MLX `set_memory_limit` | (LLM-software layer) | — | — | SCOPE | prevents kernel panic from KV growth |

Leave `vm.compressor_mode` at `4`. The better lever is sizing the model to unified memory and
bounding the KV cache, not disabling swap.

## Category 6 — File / process limits

Large model files and many worker threads can exhaust descriptor limits.

| Parameter | nix option / cmd | Default | This host | Persist | Notes |
| --- | --- | --- | --- | --- | --- |
| `kern.maxfiles` | `resourceLimits.maxFiles` | macOS default | `524288` | VOLATILE | must stay < INT_MAX (panic) |
| `kern.maxfilesperproc` | `resourceLimits.maxFilesPerProc` | macOS default | `524288` | VOLATILE | mmap'd shard sets |
| `kern.maxproc` | `resourceLimits.maxProc` | macOS default | `null` (leave) | VOLATILE | adequate for single server |
| `kern.maxprocperuid` | `resourceLimits.maxProcPerUid` | macOS default | `null` (leave) | VOLATILE | exposed for completeness |
| `launchctl limit maxfiles` | `resourceLimits.launchctlMaxFiles.{soft,hard}` | system default | `524288/524288` | per-boot | boot LaunchDaemon |

Never set a `kern.*` limit at/above INT_MAX (`2147483647`) — it is read as a negative 32-bit int and
panics macOS. The module asserts this.

## Category 7 — Background contention

Background services steal CPU, memory bandwidth, and thermal headroom.

| Parameter | nix option / cmd | Default | This host | Persist | Notes |
| --- | --- | --- | --- | --- | --- |
| Spotlight off (model vol) | `huggingfaceVolume` → `mdutil -i off` | indexing on | `/Volumes/HuggingFace` | PERSIST | or name a dir `*.noindex` |
| Time Machine excludes | `timeMachineExcludes` → `tmutil addexclusion` | none | uv/HF/app caches | PERSIST | stops snapshot churn |
| `caffeinate -i <cmd>` | (doc-only) | — | — | SCOPE | redundant: `energy.sleep.ac=0` |

Also quit cloud sync / Photos analysis / heavy browser tabs during inference — they compete for the
same unified-memory bandwidth the GPU needs.

Continued in [Part 2](MACOS-LLM-PERFORMANCE-TUNING-PT2.md).
