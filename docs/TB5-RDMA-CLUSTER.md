# Thunderbolt 5 RDMA two-Mac cluster runbook

Pool the MacBook Pro + Mac Studio (M4 Max, 128GB each) over a direct
Thunderbolt 5 cable into a 256GB MLX cluster using Apple's first-party RDMA
over Thunderbolt (macOS 26.2+, Apple TN3205) and the JACCL collective
library (TB5-only, max 4 nodes, fully-connected mesh; ~50-60 Gb/s,
single-digit-µs latency).

This file is the committed record of the physical/Recovery steps that code
cannot apply. Everything software-side (bridge networking, SSH pairing,
wired-memory limits, EXO/JACCL install) lives in nix-darwin/nix-ai modules,
not here.

## One-time RDMA enable (per Mac, physical)

`rdma_ctl status` reports `disabled` on a fresh install. Enabling requires
Recovery mode and a reboot — it cannot be scripted or remoted:

1. Shut the Mac down fully.
2. Hold the power button ~10 s until "Loading startup options", choose
   **Options** → Recovery.
3. If the enable command in step 4 is refused, first open **Utilities →
   Startup Security Utility** and set **Reduced Security** (reported as
   required by some TN3205 readings; if step 4 succeeds under Full
   Security, record that here and skip this).
4. **Utilities → Terminal**: `rdma_ctl enable`
5. Restart normally.
6. Verify from a shell: `rdma_ctl status` → `enabled`.

Repeat on the second Mac. Record the actual observed sequence (with/without
Reduced Security) in this file after the first run.

## Physical topology

- One TB5 cable, port-to-port, **no daisy-chain, no dock/hub** in the path.
- Both machines must be TB5 (M4 Max ✓); JACCL does not support TB4.

## Network substrate (two-track — do NOT bridge the RDMA path)

The RDMA transport is point-to-point and is NOT IP-over-Thunderbolt-Bridge.
EXO's own `set_rdma_network_config.sh` *disables* Thunderbolt Bridge and
sets DHCP on the RDMA ports.

- Keep an IP path (Thunderbolt Bridge or regular LAN) only for out-of-band
  bootstrap/SSH between the nodes.
- Never hardcode the `bridgeN` interface name — the index is dynamic per
  plug order and VPN state. Resolve dynamically or use link-local
  addressing.
- Assert the RDMA transport is actually active before benchmarking:
  `ibv_devices` lists the RDMA device, and EXO's startup log reports the
  transport. A working `ping` between the nodes proves only the TCP
  fallback.

## Memory sizing (per node, not per model)

`iogpu.wired_limit_mb` is sized for the node's **shard** (~66GB weights +
KV headroom → ~80-90GB ceiling on a 128GB node), never the whole pooled
model. A ~130GB wired limit on a 128GB node starves macOS and the RDMA
stack itself.

## Verification checklist

- [ ] `rdma_ctl status` → `enabled` on both Macs
- [ ] `ibv_devices` shows the TB RDMA device on both
- [ ] JACCL smoke: `mlx.launch --backend jaccl` with a small model across
      both nodes completes
- [ ] Big-model target answers a chat completion end-to-end from the MBP
