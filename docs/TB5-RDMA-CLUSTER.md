# Thunderbolt 5 RDMA two-Mac cluster — physical record

Pool the MacBook Pro + Mac Studio (M4 Max, 128 GB each) over a direct
Thunderbolt 5 cable into one MLX cluster (**200 GB aggregate model budget
while plugged in** — the sum of both wired ceilings) using Apple's
first-party RDMA over Thunderbolt (macOS 26.2+, Apple TN3205) and the JACCL
collective library (TB5-only, max 4 nodes, fully-connected mesh).

This file is the committed record of the **physical / Recovery-mode steps
that code cannot apply**. Everything else — link identity, bridge handling,
carrier rules, memory sizing, every operational rule — lives in ONE place:
nix-ai
[`docs/runbooks/cluster-link-truths.md`](https://github.com/dryvist/nix-ai/blob/develop/docs/runbooks/cluster-link-truths.md),
with the link-prep mechanism itself in `modules/darwin/cluster-link-prep.nix`
(`system.clusterLinkPrep` — the module's comments are the mechanism doc).
Component map: [CLUSTER_MODE.md](CLUSTER_MODE.md).

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
- The rendezvous address is IPv4-only (JACCL's parser rejects every IPv6
  form, validated 2026-07-11); the link addresses are module-defined
  synthetic defaults (`programs.mlx.clusterMode.staticLinkIps`).
- Use the regular LAN for out-of-band SSH between the nodes (the Thunderbolt
  Bridge service is disabled on cluster hosts — deliberately; see the truths
  page before "fixing" it).
- Assert RDMA is actually active before benchmarking: `ibv_devices` lists the
  device; a working `ping` proves only the IP path, never RDMA.

## Verification status

RDMA enabled and the link verified at 80 Gb/s both directions; production
`--pipeline` serving live on both ranks (#1746). Ongoing health is judged by
the acceptance rule in the truths page — a real completion, never a
`/v1/models` 200.
