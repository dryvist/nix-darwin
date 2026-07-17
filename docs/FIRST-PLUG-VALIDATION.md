# First-plug validation checklist

The committed checklist for the first supervised cluster session
(2026-07-16 cluster config audit). Everything code-side is merged or in PR
(#1718, #1719, #1720, nix-ai#1245); this file tracks the physical validation
that only the Thunderbolt cable can provide.

Run every item in a **supervised session**. `programs.mlx.clusterMode.enable`
stays `false` until this list is green. Record the observed result inline —
this is the durable record, the same way [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md)
holds the Recovery-mode steps and [CLUSTER_MODE.md](CLUSTER_MODE.md) holds
the plug-session ceremony.

## Checklist

- [ ] **RDMA device visible.** `ibv_devices` shows the TB RDMA device on both
  Macs. Note the real device name and whether it matches the runtime-derived
  `rdma_<iface>` default. Set `programs.mlx.clusterMode.rdmaDevice` only if it
  does not.
  - _Result:_

- [ ] **JACCL hello-world.** `mlx.launch --backend jaccl` small-model smoke
  across both nodes completes.
  - _Result:_

- [ ] **Cluster wired ceilings.** Validate `system.clusterLinkPrep`
  wired-memory limits (coordinator 90000 MB, worker 80000 MB): watch memory
  pressure and WindowServer responsiveness through a full REAP-50 load and a
  long generation on both ranks. Adjust the values and record the outcome.
  - _Result:_

- [ ] **Link-down restore.** Confirm the link-down path returns each host to
  its day wired value.
  - _Result:_

- [ ] **Readiness probe.** Confirm the coordinator watcher logs `rank ready`
  and the load-grace default (1800 s) comfortably covers the REAP-50 load.
  - _Result:_

- [ ] **Unplug test.** Yank the cable mid-generation: router falls back, ranks
  stop, day serving re-warms, worker agents restore.
  - _Result:_

- [ ] **Second cable.** Test whether JACCL uses a second link between the same
  pair (expected: no). Record the result in
  [CLUSTER_MODE.md](CLUSTER_MODE.md#second-cable).
  - _Result:_

- [ ] **Recovery-mode Reduced Security.** Record in
  [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md) whether the Recovery-mode
  `rdma_ctl enable` needed Reduced Security (step ran 2026-07-16; the doc
  still asks for the observation).
  - _Result:_

- [ ] **Reboot-with-cable-in.** Verify the quiesce-on-kickstart fix
  (nix-ai#1245) unloads day serving before the rank starts.
  - _Result:_

## Sign-off

When every box is checked and the results recorded, enable
`programs.mlx.clusterMode.enable = true` on both hosts and rebuild. Until then,
clustered mode stays off.
