# macOS Performance Tuning - Part 2

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

## Verification

```bash
# Volatile sysctls (after rebuild and again after a reboot)
sysctl iogpu.wired_limit_mb kern.maxfiles kern.maxfilesperproc
launchctl limit maxfiles

# pmset perf flags + Energy Mode (expect powermode 2 = High Power, powernap 0)
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
