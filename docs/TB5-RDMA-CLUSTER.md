# Thunderbolt 5 RDMA two-Mac cluster runbook

Pool the MacBook Pro + Mac Studio (M4 Max, 128GB each) over a direct
Thunderbolt 5 cable into a 256GB MLX cluster using Apple's first-party RDMA
over Thunderbolt (macOS 26.2+, Apple TN3205) and the JACCL collective
library (TB5-only, max 4 nodes, fully-connected mesh; ~50-60 Gb/s,
single-digit-µs latency).

This file is the committed record of the physical/Recovery steps that code
cannot apply. Everything software-side (link prep, wired-memory limits, the
`clusterMode` serving stack) lives in nix-darwin/nix-ai modules, not here —
see [CLUSTER_MODE.md](CLUSTER_MODE.md) for the component map.

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
RDMA needs. The `system.clusterLinkPrep` module owns this, idempotently, on
every boot and rebuild (root postActivation, no runtime daemon):

1. Disables the Thunderbolt Bridge network service.
2. Sweeps any Thunderbolt device still enslaved in `bridge0` out, enumerated
   from `networksetup -listallhardwareports` (not the service order — with
   no per-port services the service order carries no Thunderbolt lines at
   all in the broken state being repaired).
3. Brings every Thunderbolt device **up**. This step is not cosmetic and was
   missing until 2026-07-25: leaving `bridge0` drops a port to
   administratively down (`flags=8822`, no `UP`), a down port reports
   `status: inactive` even with a live cable, and step 4 only addresses a
   *carrier-active* device — so the sweep in step 2 silently guaranteed that
   step 4 matched nothing and assigned no address, on both hosts. It did not
   self-heal on reboot or rebuild, because those rerun the same sweep.
   Symptom: a cable connected the whole time, no link address anywhere, and
   the watcher never seeing "up" (its only link test is a ping to the peer's
   address). The prep now also logs a `WARN … was NOT assigned` line when no
   port had carrier, because postActivation runs it non-fatally and a run
   that addressed nothing otherwise reports a clean activation.
4. Puts the link IPv4 directly on the carrier-active physical Thunderbolt
   **device** via `ifconfig alias` — deliberately not a SystemConfiguration
   network service. On macOS 26, `networksetup -createnetworkservice` fails
   as root with "Unable to access the System Configuration database" even
   for un-enslaved ports (verified 2026-07-18, dryvist/nix-darwin#1750), so
   per-port services cannot be created at all on hosts that never had them.
   Only the carrier-active device gets the address — aliasing the same
   subnet on several up interfaces makes the kernel bind the /24 route to
   whichever came first, which silently blackholes traffic if the cable is
   on a different port. Persistence comes from this prep rerunning at every
   boot and rebuild, not from SystemConfiguration state; moving the cable
   heals on the next run.

This mechanism replaced an earlier one (dryvist/nix-darwin#1747) that tried
to create a per-port network service for each Thunderbolt hardware port and
set its address via `networksetup -setmanual` — that approach never worked
on macOS 26 because service creation itself fails as root (#1750).

- The rendezvous address is **IPv4 only**: the pinned mlx-lm's JACCL parser
  rejects every IPv6 form, including `[::1]:port` (validated 2026-07-11). The
  link addresses are module-defined synthetic defaults
  (`programs.mlx.clusterMode.staticLinkIps`), not site topology.
- Use the regular LAN for out-of-band bootstrap/SSH between the nodes (the
  Thunderbolt Bridge service is disabled on cluster hosts).
- Never hardcode the interface name anywhere — the prep enumerates every
  Thunderbolt device and addresses only the carrier-active one, so moving
  the cable to a different port heals on the next boot/rebuild with no
  config change.
- Assert the RDMA transport is actually active before benchmarking:
  `ibv_devices` lists the RDMA device. A working `ping` between the nodes
  proves only the IP path, not RDMA.

## Memory sizing (per node, not per model)

`iogpu.wired_limit_mb` is sized for the node's **shard** (~half the pipeline
model's weights + KV headroom), never the whole pooled model. A shard-sized
wired allocation that crowds the GUI working set starves macOS and the RDMA
stack itself — this is not theoretical: the 2026-07-12 auto-bring-up wired a
~99 GB shard per node and kernel-panicked BOTH hosts (WindowServer watchdog).
The mitigation is live as of #1746: `system.clusterLinkPrep.clusterWiredLimitMb`
caps each rank's ceiling before it starts and restores the standalone value at
link-down.

The 90000 MB coordinator / 80000 MB worker caps this page used to name are
**retired** — they were low enough to force swap. `clusterWiredLimitMb` now
derives from the host's own standalone ceiling
(`config.system.appleSiliconTunables.wiredLimitMb`), so there is no separate
clustered number for this page to hold. Read the value from the config, never
from here. See [CLUSTER_MODE.md](CLUSTER_MODE.md) for current status.

## Verification checklist

- [x] `rdma_ctl status` → `enabled` on both Macs (2026-07-16)
- [x] `ibv_devices` shows the TB RDMA device on both — link verified up at
      80 Gb/s in both directions (#1746)
- [x] JACCL smoke: production `--pipeline` serving is live on both ranks
      (#1746)
- [ ] Big-model target answers a chat completion end-to-end from the MBP —
      **(verify)**: a real request reached prefill and then hung mid-generation
      in the 2026-07-17/18 session (nix-ai#1275, open); a clean end-to-end
      completion is not yet separately confirmed.

The full first-plug supervised run is tracked in
[FIRST-PLUG-VALIDATION.md](FIRST-PLUG-VALIDATION.md), including
whether the Recovery-mode `rdma_ctl enable` needed Reduced Security (record
that observation in the one-time-enable section above).
