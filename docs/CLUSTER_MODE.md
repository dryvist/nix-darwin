# Cluster mode — two-Mac Thunderbolt 5 distributed brain

One TB5 cable turns the two M4 Max / 128 GB Macs into a single inference
cluster serving a frontier-class model neither machine can hold alone. The
model budget while plugged in is the **aggregate of both wired ceilings
(2 × 102400 MB ≈ 200 GB)** — never one host's 100 GB. Plugging in is the
entire ceremony; unplugging reverses everything unattended.

> **Every cluster rule lives in ONE page:** nix-ai
> [`docs/runbooks/cluster-link-truths.md`](https://github.com/dryvist/nix-ai/blob/develop/docs/runbooks/cluster-link-truths.md)
> — plugged-in-means-clustered (self-correcting, lease-gated), the
> generation-parity hard gate, the aggregate budget, the observation traps,
> and what the automation enforces for each. Bring-up / safe-unplug procedure:
> nix-ai
> [`docs/runbooks/cluster-lifecycle.md`](https://github.com/dryvist/nix-ai/blob/develop/docs/runbooks/cluster-lifecycle.md).
> This page holds only what is nix-darwin-specific. The former plug-session
> checklists and lesson prose here are superseded by those pages; history is
> in git.

Status: `programs.mlx.clusterMode.enable = true` on both hosts since #1746.
RDMA is enabled on both Macs; the link runs at 80 Gb/s both directions.
Physical/Recovery-mode steps: [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md).

## Component map (all IaC)

| Piece | Where |
| --- | --- |
| `programs.mlx.clusterMode` (ranks, link watcher, lifecycle commands, prefetch, log rotation) | nix-ai `modules/mlx/` |
| Host roles (coordinator = server, worker = workstation) | `lib/hosts/*.nix` (`clusterMode.role`) |
| Static link config (bridge off, role IPv4) + wired-ceiling grants | `modules/darwin/cluster-link-prep.nix` (`system.clusterLinkPrep`) |
| Worker quiesce/restore (GUI quit + agent allowlist sweep) | `hosts/common/cluster-quiesce.nix` + `scripts/cluster-{quiesce,restore}.sh` |
| Gated cluster endpoint (`:11440`, same bearer token) | `modules/darwin/llm-gate.nix` `clusterUpstreamPort` / `clusterPort` |
| Router: cluster brain in the large phase + solo fallback | ansible-proxmox-apps `roles/llm_router` |
| Log shipping (`in_cluster_logs`, gate `cluster-access.json`) | `hosts/common/cribl.nix` |

## Model and ceilings (read values from config, never from docs)

Production cluster model: `GLM-4.7-REAP-50-mxfp4` (98.2 GB, ~49 GB/rank) —
the expert-pruned build halves the per-rank shard so it fits each host's
ceiling with KV headroom. The full `GLM-4.7-4bit` (198 GB) fits the
**aggregate** budget but needs the per-host shard revalidated before use.

`clusterWiredLimitMb` derives from the host's own standalone ceiling
(`config.system.appleSiliconTunables.wiredLimitMb`, 102400 on both), so the
ceiling does not change at link-up/-down and `set_wired_limit` is a no-op
here. Per-host ceilings are single-host safety guards; cluster capacity is
their sum. The retired 90000/80000 differential caps must not be cited.

## Observability

`in_cluster_logs` ships rank/watcher/prefetch logs; the gate's
`cluster-access.json` rides the existing gate input (both → index=llm).
Saved-search ideas and the acceptance rule (a real completion, never a
`/v1/models` 200) are in the canonical truths page.
