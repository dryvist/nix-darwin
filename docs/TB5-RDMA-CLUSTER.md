# Thunderbolt 5 RDMA two-Mac cluster runbook

Pool the MacBook Pro + Mac Studio (M4 Max, 128GB each) over a direct
Thunderbolt 5 cable into a 256GB MLX cluster using Apple's first-party RDMA
over Thunderbolt (macOS 26.2+, Apple TN3205) and the JACCL collective
library (TB5-only, max 4 nodes, fully-connected mesh; ~50-60 Gb/s,
single-digit-µs latency).

This file is the committed record of the physical/Recovery steps that code
cannot apply. Everything software-side (link prep, wired-memory limits, the
`clusterMode` serving stack) lives in nix-darwin/nix-ai modules, not here —
see [NIGHT_CLUSTER.md](NIGHT_CLUSTER.md) for the component map.

## One-time RDMA enable (per Mac, physical) — DONE 2026-07-16

**Status: `rdma_ctl status` reports `enabled` on BOTH Macs as of 2026-07-16.**
The procedure below stays as the record for any future Mac joining the mesh.

`rdma_ctl status` reports `disabled` on a fresh install. Enabling requires
Recovery mode and a reboot — it cannot be scripted or remoted (verified
2026-07-10: `rdma_ctl enable` on the booted OS refuses with "This tool needs
to be executed from Recovery OS", exit 77, even as root):

1. Shut the Mac down fully.
2. Hold the power button ~10 s until "Loading startup options", choose
   **Options** → Recovery.
3. If the enable command in step 4 is refused, first open **Utilities →
   Startup Security Utility** and set **Reduced Security** (reported as
   required by some TN3205 readings; record here whether it was needed).
4. **Utilities → Terminal**: `rdma_ctl enable`
5. Restart normally.
6. Verify from a shell: `rdma_ctl status` → `enabled`.

## Physical topology

- One TB5 cable, port-to-port, **no daisy-chain, no dock/hub** in the path.
- Both machines must be TB5 (M4 Max ✓); JACCL does not support TB4.

## Network substrate (two-track — do NOT bridge the RDMA path)

The RDMA transport is point-to-point and is NOT IP-over-Thunderbolt-Bridge.
macOS keeps re-enslaving Thunderbolt ports into the "Thunderbolt Bridge"
network service (device bridge0), which breaks the exclusive L2 that Apple
RDMA needs. The `system.clusterLinkPrep` module owns this: at activation it
disables the bridge0 network service when an RDMA link is active, and its
`cluster-link-converge` root daemon (30 s tick) detaches the cabled port from
bridge0 and converges this host's role-derived link IPv4 onto it.

- The rendezvous address is **IPv4 only**: the pinned mlx-lm's JACCL parser
  rejects every IPv6 form, including `[::1]:port` (validated 2026-07-11). The
  link addresses are module-defined synthetic defaults
  (`programs.mlx.clusterMode.staticLinkIps`), not site topology.
- Keep an IP path (Thunderbolt Bridge on another port, or the regular LAN)
  only for out-of-band bootstrap/SSH between the nodes.
- Never hardcode the interface name — the cabled port is auto-detected each
  tick, so moving the cable to another port converges with no config change.
- Assert the RDMA transport is actually active before benchmarking:
  `ibv_devices` lists the RDMA device, and the rank log prints the resolved
  `iface`/`dev`/coordinator line at startup. A working `ping` between the
  nodes proves only the IP fallback path.

## Memory sizing (per node, not per model)

`iogpu.wired_limit_mb` is sized for the node's **shard** (~half the pipeline
model's weights + KV headroom), never the whole pooled model. A shard-sized
wired allocation that crowds the GUI working set starves macOS and the RDMA
stack itself — this is not theoretical: the 2026-07-12 auto-bring-up wired a
~99 GB shard per node and kernel-panicked BOTH hosts (WindowServer watchdog).
Clustered mode stays disabled until a wired-headroom mitigation provably
leaves the GUI working set unwirable on each node.

## Verification checklist

- [x] `rdma_ctl status` → `enabled` on both Macs (2026-07-16)
- [ ] `ibv_devices` shows the TB RDMA device on both
- [ ] JACCL smoke: `mlx.launch --backend jaccl` with a small model across
      both nodes completes
- [ ] Big-model target answers a chat completion end-to-end from the MBP
