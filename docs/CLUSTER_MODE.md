# Cluster mode — two-Mac Thunderbolt 5 distributed brain

One Thunderbolt 5 cable turns the two M4 Max / 128 GB Macs into a single
256 GB inference cluster running a frontier-class model neither machine can
hold alone — and the rest of the fabric never notices the seam. Plugging in
is the entire ceremony; unplugging reverses everything unattended.

> **STATUS (2026-07-16): clustered mode is DISABLED on both hosts.** The
> 2026-07-12 boot-time auto-bring-up wired a ~99 GB rank shard and starved
> WindowServer into a watchdog kernel panic on both Macs. Re-enable
> `programs.mlx.clusterMode.enable` only together with a wired-headroom
> mitigation that provably leaves the GUI working set unwirable, and only in a
> supervised session. RDMA itself is ready: `rdma_ctl` reports `enabled` on
> both Macs (Recovery step completed 2026-07-16).

Component map (all IaC):

| Piece | Where |
| --- | --- |
| `programs.mlx.clusterMode` (ranks, link watcher, prefetch, log rotation) | nix-ai `modules/mlx/cluster-mode.nix` + `cluster-mode-maintenance.nix` |
| Host roles (coordinator = server, worker = workstation) | `lib/hosts/*.nix` (`clusterMode.role`) |
| Static link config (bridge off, role IPv4) + wired-ceiling grants | `modules/darwin/cluster-link-prep.nix` (`system.clusterLinkPrep`) |
| Worker quiesce/restore (GUI quit + agent allowlist sweep) | `hosts/common/cluster-quiesce.nix` + `scripts/cluster-{quiesce,restore}.sh` |
| Gated cluster endpoint (`:11440`, same bearer token) | `modules/darwin/llm-gate.nix` `clusterUpstreamPort` / `clusterPort` |
| Router: cluster brain in the large phase + solo fallback | ansible-proxmox-apps `roles/llm_router` (`ai_night_brain_enabled`) |
| Log shipping (`in_cluster_logs`, gate `cluster-access.json`) | `hosts/common/cribl.nix` |

Serving stack: first-party **mlx-lm** — `mlx_lm.server --pipeline` on both
ranks (rank 0 binds the OpenAI-compatible endpoint; both ranks join every
generation). Distributed init uses the documented env contract
(`MLX_RANK` / `MLX_JACCL_COORDINATOR` / `MLX_IBV_DEVICES`,
`MLX_METAL_FAST_SYNCH=1`), so each Mac starts its own rank from launchd — no
SSH orchestration. `--pipeline` is required: the pinned mlx-lm ships
`PipelineMixin` for `glm4_moe` but not tensor-parallel `shard()`; revisit TP
on an mlx-lm bump.

Link identity: **role-derived synthetic IPv4** addresses
(`clusterMode.staticLinkIps`), applied statically at activation — the
Thunderbolt Bridge network service is disabled and every physical Thunderbolt
port's service carries the same manual role address, so whichever port the
cable lands in has the address with zero runtime logic. IPv6 link-local was
validated 2026-07-11 and REJECTED — the pinned mlx-lm's JACCL rendezvous
parser is IPv4-only.

**Cluster model**: `GLM-4.7-4bit` (352.8B, 198 GB — `glm4_moe`). It is the
only frontier-class (>128 GB) architecture with distributed support in the
pinned mlx-lm. Qwen3-235B (`qwen3_moe`) and Qwen3.5-397B (`qwen3_5_moe`) have
**no** shard/pipeline support upstream yet (ml-explore/mlx-lm#1138 stale since
April 2026) — recheck before every bench session; either landing would make a
strong head-to-head candidate. `GLM-4.7-REAP-50-mxfp4` (98.2 GB, same
`glm4_moe` arch, ~49 GB/rank) is the memory-safe candidate while the
wired-headroom mitigation is unproven.

## One-time prep (BEFORE the first plug session — no cable needed)

1. **Enable RDMA on BOTH Macs** — DONE 2026-07-16 (`rdma_ctl status` →
   `enabled` on both). Procedure recorded in
   [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md).
2. **Confirm weights on both Macs**: the `dev.mlx-cluster.prefetch` agent
   downloads the cluster model into `$HF_HOME` on each host (retry-until-
   complete). `hf download <model>` resumes manually if needed; mirroring the
   workstation's cache over the second TB cable beats re-downloading 198 GB.
3. **Dry-run the worker quiesce WITHOUT a cable**: run `cluster-quiesce`, then
   assert the agent table matches the allowlist
   (`launchctl list | grep -v com.apple`), then `cluster-restore` and confirm
   the recorded agents return.
4. **Check the fabric config is live**: rebuild both Macs; confirm
   `launchctl print gui/$UID/dev.mlx-cluster.watcher` exists on both and the
   rank agent is idle (link down → watcher no-ops).

The first supervised session runs the
[first-plug validation checklist](FIRST-PLUG-VALIDATION.md) and records each
observed result there; `programs.mlx.clusterMode.enable` stays `false` until
that list is green.

## Plug-session checklist (execution only — zero code)

1. No manual IP step: activation already disabled the Thunderbolt Bridge
   service and pinned this host's role link address on every Thunderbolt
   port.
2. Cable #1 in (the RDMA rail). Verify: `ibv_devices` shows the device on
   both; note the real device name and correct
   `programs.mlx.clusterMode.rdmaDevice` per host if it differs from the
   default (`rdma_en2`) — the `MLX_IBV_DEVICES` matrix ships UNVALIDATED
   until this step. Optionally run
   `mlx.distributed_config --over thunderbolt --backend jaccl --hosts …`
   to cross-check the generated hostfile against the module's env contract.
3. JACCL hello-world: `mlx.launch --backend jaccl --hostfile <generated> --
   python -c 'import mlx.core as mx; print(mx.distributed.init().rank())'`
   (or watch the two rank logs — the watcher will have started the ranks
   as soon as the peer ping succeeded).
4. Watch the seam: `cluster-watcher.log` on both Macs shows
   `down -> up` → day models unload (coordinator) / quiesce sweep (worker) →
   rank kickstart. First token can take minutes (198 GB load).
5. Smoke the endpoint through the gate:
   `curl -H "Authorization: Bearer $TOKEN" https://<serving-host>:11440/v1/models`.
6. Flip the router: set `ai_night_brain_enabled: true` (+ `ai_night_model`,
   `ai_night_context_window`, and the `llm_night_api` port constant in the
   tofu registry — variable names owned by the router/tofu repos), converge
   the routers. Large phase now serves `ai-default` on the cluster brain with
   the solo 80B as automatic fallback.
7. Bench: two runs on the cluster model (verdict-maturity rule: results stay
   PROVISIONAL until ≥4 runs / ≥5 days). Then let Hermes's scheduled digest
   run on it.
8. **Unplug test before ending the session is optional but recommended**:
   yank the cable — in-flight generations abort, LiteLLM falls back to the
   solo brain, the watcher stops the rank and re-warms day serving.
   Surprise-yank and graceful shutdown converge on the same code path; there
   is no hardware or filesystem risk (each Mac's memory is its own).

> **Reboot-with-cable-in caveat:** the watcher's link-state file survives a
> reboot. A host that reboots with the cable still in comes up seeing
> `up -> up`, so the down→up quiesce (day-model unload / worker sweep) is
> skipped while the rank is kickstarted — day serving and the rank then
> contend for wired memory. Until the watcher re-quiesces on kickstart, pull
> the cable before any reboot.

## Unplug

Pull the cable (glance that no generation is mid-stream if you care about
it finishing). Everything reverses unattended: ranks exit, day workers
restart and re-warm, the worker's booted-out agents bootstrap back, the
12:00 UTC flip proceeds as always. GUI apps stay closed.

## Second cable

A 2-node JACCL cluster is fully connected with ONE cable. Cable #2 was
envisioned as a control/mirror rail over the Thunderbolt Bridge — but the
bridge service is now disabled on cluster hosts (RDMA needs exclusive L2),
so a second rail needs its own addressing scheme; design it when the mirror
need is real. The cable remains the single physical failure point; whether
JACCL uses a second link between the same pair is expected to be "no" —
test once and record the result here.

## Observability

- `in_cluster_logs` ships rank/watcher/prefetch logs; the gate's
  `cluster-access.json` rides the existing gate input (both → index=llm).
- Saved searches (ansible-splunk): cluster-rank crash/JACCL-error detector;
  "cluster mode active but no cluster-brain tokens in 30 min"; worker
  quiesce-violation (unexpected agent during a cluster window).
- The memory-headroom alert and verdict-maturity benchmarking extend to the
  cluster brain unchanged.
