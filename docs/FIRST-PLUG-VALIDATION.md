# First-plug validation record (historical)

**Superseded 2026-07-18: cluster mode is live.** The supervised first-plug
session this checklist gated ran 2026-07-17/18 and shipped as #1746 —
`programs.mlx.clusterMode.enable = true` on both hosts, running the
`GLM-4.7-REAP-50-mxfp4` production model. This file is kept as the durable
record of what was and was not directly observed during that session, the
same way [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md) holds the Recovery-mode
steps and [CLUSTER_MODE.md](CLUSTER_MODE.md) holds current status.

Two link-IP bugs (#1747, #1750) were found and fixed live during this same
session — see [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md#network-substrate-two-track--do-not-bridge-the-rdma-path)
for the corrected mechanism.

## Checklist

- [x] **RDMA device visible.** `ibv_devices` shows the TB RDMA device on both
  Macs; the Thunderbolt link is verified up at 80 Gb/s in both directions.
  - _Result:_ Confirmed 2026-07-16/18. `rdmaDevice` left at the `rdma_en2`
    default on both hosts (no override needed).

- [x] **JACCL hello-world.** `mlx.launch --backend jaccl` / the production
  `--pipeline` rank start across both nodes completes.
  - _Result:_ Confirmed — both ranks reach `mx.distributed.init()` and load
    their REAP-50 shard in production (#1746).

- [x] **Cluster wired ceilings.** `system.clusterLinkPrep` wired-memory
  limits were live during this session (coordinator 90000 MB, worker
  80000 MB) and bounded the REAP-50 shard's wired load.
  - _Result:_ Values deployed and active. No repeat of the 2026-07-12
    WindowServer panic observed. **(verify)**: whether they were
    stress-tested under a long generation with the GUI working set under
    separate memory pressure is not separately confirmed.
  - _Superseded 2026-07-19:_ these differential caps are gone.
    `clusterWiredLimitMb` now equals the host's standalone
    `appleSiliconTunables.wiredLimitMb` (102400 MB on both), so the ceiling
    no longer changes at link-up. Do not cite the 90000/80000 numbers as a
    current guard — see
    [CLUSTER-RESUMPTION-DRILL.md](CLUSTER-RESUMPTION-DRILL.md) §2.

- [ ] **Link-down restore.** Confirm the link-down path returns each host to
  its standalone wired value.
  - _Result:_ **(verify)** — not directly confirmed in this session's record.
    Note that since the 2026-07-19 change the two values are identical, so
    this box can no longer be closed by observing the sysctl; it now means
    only "the teardown ran". Drill Phase 5 covers it.

- [x] **Readiness probe.** Confirm the coordinator watcher logs `rank ready`.
  - _Result:_ Confirmed the coordinator's rank reached readiness (one
    successful `/v1/models` probe). **Caveat found live**: readiness is a
    one-shot latch never re-verified after that point, and the worker has no
    post-start hang detection at all — tracked as nix-ai#1275 (open), not a
    first-plug blocker but a known operational gap going forward.

- [ ] **Unplug test.** Yank the cable mid-generation: router falls back, ranks
  stop, standalone serving re-warms, worker agents restore.
  - _Result:_ **(verify)** — not directly confirmed in this session's record.

- [ ] **Second cable.** Test whether JACCL uses a second link between the same
  pair (expected: no). Record the result in
  [CLUSTER_MODE.md](CLUSTER_MODE.md#second-cable).
  - _Result:_ **(verify)** — not tested.

- [ ] **Recovery-mode Reduced Security.** Record in
  [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md) whether the Recovery-mode
  `rdma_ctl enable` needed Reduced Security.
  - _Result:_ **(verify)** — not recorded; RDMA enable predates this session
    (2026-07-16).

- [ ] **Reboot-with-cable-in.** Verify the quiesce-on-kickstart fix
  (nix-ai#1245) unloads standalone serving before the rank starts.
  - _Result:_ **(verify)** — not directly confirmed in this session's record.

## Sign-off

Cluster mode went live 2026-07-18 (#1746) on the strength of the checked
items above — the core gating risk (wired-headroom panic) has a live
mitigation and RDMA/JACCL are confirmed working end-to-end in production.
The unchecked items are real gaps in the validation record, not known
failures; verify them opportunistically rather than treating this file as
still gating `enable`.
