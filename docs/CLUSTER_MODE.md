# Cluster mode — two-Mac Thunderbolt 5 distributed brain

One Thunderbolt 5 cable turns the two M4 Max / 128 GB Macs into a single
256 GB inference cluster running a frontier-class model neither machine can
hold alone — and the rest of the fabric never notices the seam. Plugging in
is the entire ceremony; unplugging reverses everything unattended.

> **STATUS (2026-07-18): clustered mode is ENABLED on both hosts.**
> `programs.mlx.clusterMode.enable = true` shipped for coordinator and worker
> together in the supervised re-enable session (#1746) the 2026-07-12 disable
> note called for.
> **Wired-ceiling correction (2026-07-24):** the differential caps this note
> used to advertise (90000 MB coordinator / 80000 MB worker) were superseded
> on 2026-07-19. `hosts/common/default.nix` now sets
> `clusterWiredLimitMb = config.system.appleSiliconTunables.wiredLimitMb`, so
> the clustered and standalone ceilings are the SAME value on both hosts
> (102400 MB). The watcher's `set_wired_limit` is therefore a no-op at both
> link-up and link-down, and its "wired ceiling not applied; NOT starting the
> rank" interlock can never fire. Today's guards are the ~28 GiB OS reserve
> inside that ceiling, the worker's GUI quiesce, and the join/detach swap
> gates — not a ceiling flip. See
> [CLUSTER-RESUMPTION-DRILL.md](CLUSTER-RESUMPTION-DRILL.md) §2.
> RDMA is enabled on both Macs (`rdma_ctl status` →
> `enabled`, 2026-07-16) and the Thunderbolt link is verified up at 80 Gb/s in
> both directions (full TB5 symmetric speed). The link-IP assignment
> mechanism changed in #1747/#1750 — see
> [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md) for the corrected mechanism.
> **Known gap:** the link watcher's readiness check is a one-shot latch with
> no post-start hang detection on the worker, so a mid-generation wedge on
> either rank can run silently — tracked in nix-ai#1275 (open).

Component map (all IaC):

| Piece | Where |
| --- | --- |
| `programs.mlx.clusterMode` (ranks, link watcher, prefetch, log rotation) | nix-ai `modules/mlx/cluster-mode.nix` + `cluster-mode-maintenance.nix` |
| Host roles (coordinator = server, worker = workstation) | `lib/hosts/*.nix` (`clusterMode.role`) |
| Static link config (bridge off, role IPv4) + wired-ceiling grants | `modules/darwin/cluster-link-prep.nix` (`system.clusterLinkPrep`) |
| Worker quiesce/restore (GUI quit + agent allowlist sweep) | `hosts/common/cluster-quiesce.nix` + `scripts/cluster-{quiesce,restore}.sh` |
| Gated cluster endpoint (`:11440`, same bearer token) | `modules/darwin/llm-gate.nix` `clusterUpstreamPort` / `clusterPort` |
| Router: cluster brain in the large phase + solo fallback | ansible-proxmox-apps `roles/llm_router` (`ai_night_brain_enabled`, pending rename) |
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
(`clusterMode.staticLinkIps`), applied by root postActivation
(`system.clusterLinkPrep`) on every boot and rebuild — not a one-time
activation step and not a SystemConfiguration network service. macOS 26
cannot create per-port Thunderbolt network services at all
(`networksetup -createnetworkservice` fails as root with "Unable to access
the System Configuration database", #1750), so the link IPv4 goes directly on
the carrier-active physical Thunderbolt device via `ifconfig alias`; the
Thunderbolt Bridge service is still disabled and swept out of `bridge0`
first. Whichever port the cable lands in gets the address on the next prep
run — see [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md) for the full mechanism.
IPv6 link-local was validated 2026-07-11 and REJECTED — the pinned mlx-lm's
JACCL rendezvous parser is IPv4-only.

**Cluster model**: `GLM-4.7-REAP-50-mxfp4` (98.2 GB, `glm4_moe`, ~49 GB/rank)
is the confirmed production model as of #1746 — the expert-pruned build
halves the per-rank shard so it fits under the wired ceiling with real KV
headroom. The full `GLM-4.7-4bit` (352.8B, 198 GB) remains the module default
(`programs.mlx.clusterMode.model`) and the only other frontier-class
(>128 GB) architecture with distributed support in the pinned mlx-lm, but
both hosts explicitly override it to REAP-50; running the full weights would
need the wired ceiling re-validated for the larger shard. Qwen3-235B
(`qwen3_moe`) and Qwen3.5-397B (`qwen3_5_moe`) have **no** shard/pipeline
support upstream yet (ml-explore/mlx-lm#1138 stale since April 2026) —
recheck before every bench session; either landing would make a strong
head-to-head candidate.

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

The supervised first-plug session ran 2026-07-17/18 and is recorded in
[FIRST-PLUG-VALIDATION.md](FIRST-PLUG-VALIDATION.md);
`programs.mlx.clusterMode.enable` is `true` on both hosts as of #1746.

## Plug-session checklist (execution only — zero code)

1. No manual IP step: `cluster-link-prep` already disabled the Thunderbolt
   Bridge service and pinned this host's role link address on the
   carrier-active Thunderbolt device via `ifconfig alias` (reruns every boot
   and rebuild — see [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md)).
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
   `down -> up` → standalone models unload (coordinator) / quiesce sweep (worker) →
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
   solo brain, the watcher stops the rank and re-warms standalone serving.
   Surprise-yank and graceful shutdown converge on the same code path; there
   is no hardware or filesystem risk (each Mac's memory is its own).

> **Reboot-with-cable-in caveat:** the watcher's link-state file survives a
> reboot. A host that reboots with the cable still in comes up seeing
> `up -> up`, so the down→up quiesce (standalone-model unload / worker sweep) is
> skipped while the rank is kickstarted — standalone serving and the rank then
> contend for wired memory. Until the watcher re-quiesces on kickstart, pull
> the cable before any reboot.

## Unplug

Pull the cable (glance that no generation is mid-stream if you care about
it finishing). Everything reverses unattended: ranks exit, standalone workers
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
- **Known gap (nix-ai#1275, open)**: the coordinator's readiness check is a
  one-shot latch — once a rank answers one `/v1/models` probe it is never
  re-verified, so a mid-generation hang runs silently past the load-grace
  timer. The worker has no post-start hang detection at all. A wedge can sit
  for 90+ minutes with the watcher reporting nothing.
