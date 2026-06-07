# macOS Performance Tuning for Local LLM Inference

Exhaustive reference for every macOS / hardware-layer knob that can affect local LLM inference on
this machine — **Apple Silicon M4 Max MacBook Pro, 128 GB unified memory, macOS Tahoe 26.x**
(frameworks: MLX / vllm-mlx, llama.cpp, Ollama, LM Studio).

Every parameter is recorded here even when left at its macOS default, so the OS surface is fully
documented. Knobs that this repo wires declaratively link to their nix option; knobs that cannot be
set from nix (or belong to the LLM-software layer) are marked accordingly.

## Scope boundary

This repo (`nix-darwin`) owns the **OS / launchd layer**: `sysctl`, `pmset`, `launchd`
daemons/agents (incl. environment), `defaults`, filesystem. The **LLM-software layer** — MLX
process-level memory limits, KV-cache bounds, llama.cpp/Ollama runtime flags — is tuned separately
and is listed under [Owned by the LLM-software layer](#owned-by-the-llm-software-layer-not-os-config)
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
| App Nap disabled for | `appNapDisabledFor` | App Nap on | `[dev.vllm-mlx.server]` | PERSIST | per-app `NSAppSleepDisabled` |
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
| Time Machine excludes | `timeMachineExcludes` → `tmutil addexclusion` | none | uv/screenpipe/HF caches | PERSIST | stops snapshot churn |
| `caffeinate -i <cmd>` | (doc-only) | — | — | SCOPE | redundant: `energy.sleep.ac=0` |

Also quit cloud sync / Photos analysis / heavy browser tabs during inference — they compete for the
same unified-memory bandwidth the GPU needs.

## Category 8 — Metal / GPU specifics

| Parameter | nix option / cmd | Default | This host | Persist | Notes |
| --- | --- | --- | --- | --- | --- |
| `MTL_*` debug/validation | `metalDebugEnvToUnset` → `launchctl unsetenv` | unset | 5 vars cleared + verified | SCOPE | any set silently taxes inference |
| Metal shader/pipeline cache | (leave on) | on | on | PERSIST | faster warm starts — do not disable |

Cleared vars: `MTL_DEBUG_LAYER`, `MTL_SHADER_VALIDATION`, `MTL_SHADER_VALIDATION_DEFAULT_STATE`,
`MTL_CAPTURE_ENABLED`, `MTL_HUD_ENABLED`. This is a best-effort launchd guard with verification; the
canonical fix is for the inference LaunchAgent (nix-ai `programs.mlx`) to never export them.

## Category 9 — macOS Tahoe 26.x specifics

Doc-only — no single-box knob.

- **Metal 4** (new compute API generation); MLX / Core ML build on it. Keep macOS patched (≥ 26.2)
  for the latest MLX/Metal performance work.
- **M5 neural-accelerator path lands in 26.2** — **not** available on M4 Max; this machine still
  benefits from general Metal 4 / MLX improvements.
- **Thunderbolt 5 clustering (80 Gb/s)** — pool unified memory across Macs; future multi-box only.
- `iogpu.wired_limit_mb` remains the Tahoe-era key (vs legacy `debug.iogpu.wired_limit`); no change
  to the 75%/66% default split.

## Category 10 — Network stack (serving over LAN only)

Off by default — loopback inference does not need it. Enable + set buffers only on a measured
bottleneck. Constraint: `kern.ipc.maxsockbuf` ≥ `sendspace + recvspace` (module asserts it).

| Parameter | nix option / cmd | Default | This host | Persist | Typical tuned |
| --- | --- | --- | --- | --- | --- |
| enable | `networkTuning.enable` | — | `false` | — | — |
| `kern.ipc.maxsockbuf` | `networkTuning.maxSockBuf` | macOS default | `null` (leave) | VOLATILE | `8388608` |
| `net.inet.tcp.sendspace` | `networkTuning.tcpSendSpace` | macOS default | `null` (leave) | VOLATILE | `1048576` |
| `net.inet.tcp.recvspace` | `networkTuning.tcpRecvSpace` | macOS default | `null` (leave) | VOLATILE | `1048576` |
| `net.inet.tcp.win_scale_factor` | `networkTuning.tcpWinScaleFactor` | macOS default | `null` (leave) | VOLATILE | `8` |
| `net.inet.tcp.autorcvbufmax` | `networkTuning.tcpAutoRcvBufMax` | macOS default | `null` (leave) | VOLATILE | `33554432` |
| `net.inet.tcp.autosndbufmax` | `networkTuning.tcpAutoSndBufMax` | macOS default | `null` (leave) | VOLATILE | `33554432` |

---

## Owned by the LLM-software layer (not OS config)

Tuned in the LLM-software session, recorded here so the boundary is explicit:

- **MLX (process scope):** `mx.set_wired_limit`, `mx.set_memory_limit`, `mx.set_cache_limit`,
  `mx.clear_cache`; KV-cache bounding (`--max-kv-size`). Defense-in-depth against the kernel-panic
  class — the OS `iogpu.wired_limit_mb` cap alone does not prevent it.
- **llama.cpp flags:** `-ngl 999` (offload all layers), `-fa` (flash attention), `--mlock`,
  `-t 12` (P-core count), `-c <ctx>`. `--mlock` interacts with the OS wired-memory cap.
- **Ollama env (`OLLAMA_FLASH_ATTENTION`, `OLLAMA_KV_CACHE_TYPE=q8_0`, etc.):** N/A on this host —
  Ollama is disabled (vllm-mlx is primary). If re-enabled it would be a LaunchAgent
  `EnvironmentVariables` block in nix-ai, not here.

## Verification

```bash
# Volatile sysctls (after rebuild and again after a reboot)
sysctl iogpu.wired_limit_mb kern.maxfiles kern.maxfilesperproc
launchctl limit maxfiles

# pmset perf flags + Energy Mode (look for lowpowermode 0, powernap 0, powermode)
pmset -g custom

# Boot LaunchDaemon logs
tail /var/log/set-iogpu-wired-limit.log /var/log/set-resource-limits.log

# Metal debug env should be empty
launchctl getenv MTL_DEBUG_LAYER
```

A reboot confirms the `RunAtLoad` daemons re-apply the VOLATILE sysctls. The Energy Mode WARN appears
in activation output until High Power Mode is toggled in System Settings.

## Sources

- Apple — About Power Modes on your Mac: <https://support.apple.com/en-us/101613>
- llama.cpp — Adjust VRAM/RAM split on Apple Silicon (Discussion #2182):
  <https://github.com/ggml-org/llama.cpp/discussions/2182>
- MLX Metal docs (memory limits): <https://ml-explore.github.io/mlx/build/html/python/metal.html>
- mlx-lm #883 — kernel panic from unbounded memory: <https://github.com/ml-explore/mlx-lm/issues/883>
- Eclectic Light — Core types / you can't promote threads:
  <https://eclecticlight.co/2024/12/17/tune-for-performance-core-types/>
- Der Flounder — pmset on macOS Tahoe 26.5:
  <https://derflounder.wordpress.com/2026/05/12/using-pmset-to-set-your-mac-to-automatically-power-on-when-power-is-available-on-macos-tahoe-26-5-0/>
- Apple — Validating your app's Metal shader usage:
  <https://developer.apple.com/documentation/xcode/validating-your-apps-metal-shader-usage/>
- AppleInsider — macOS Tahoe 26.2 M5 machine-learning speed boost:
  <https://appleinsider.com/articles/25/11/18/macos-tahoe-262-will-give-m5-macs-a-giant-machine-learning-speed-boost>
- ESnet Fasterdata — macOS host (network) tuning: <https://fasterdata.es.net/host-tuning/osx/>
