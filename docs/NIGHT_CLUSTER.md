# Night Cluster — two-Mac Thunderbolt 5 distributed brain

Every night, one Thunderbolt 5 cable turns the two M4 Max / 128 GB Macs into a
single 256 GB inference cluster running a frontier-class model neither machine
can hold alone — and the rest of the fabric never notices the seam. Plugging
in is the entire ceremony; unplugging in the morning reverses everything
unattended.

Component map (all IaC):

| Piece | Where |
| --- | --- |
| `programs.mlx.nightCluster` (ranks, link watcher, prefetch) | nix-ai `modules/mlx/night-cluster.nix` |
| Host roles (coordinator = server, worker = workstation) | `lib/hosts/*.nix` |
| Worker quiesce/restore (GUI quit + agent allowlist sweep) | `hosts/common/night-quiesce.nix` + `scripts/` |
| Gated night endpoint (`:11440`, same bearer token) | `modules/darwin/llm-gate.nix` `nightUpstreamPort` |
| Router: night brain in the large phase + solo fallback | ansible-proxmox-apps `roles/llm_router` (`ai_night_brain_enabled`) |
| Log shipping (`in_night_logs`, `night-access.*`) | `hosts/common/cribl.nix` |

Serving stack: first-party **mlx-lm** — `mlx_lm.server --pipeline` on both
ranks (rank 0 binds the OpenAI-compatible endpoint; both ranks join every
generation). Distributed init uses the documented env contract
(`MLX_RANK` / `MLX_JACCL_COORDINATOR` / `MLX_IBV_DEVICES`,
`MLX_METAL_FAST_SYNCH=1`), so each Mac starts its own rank from launchd — no
SSH orchestration. `--pipeline` is required: the pinned mlx-lm ships
`PipelineMixin` for `glm4_moe` but not tensor-parallel `shard()`; revisit TP
on an mlx-lm bump.

**Night model**: `GLM-4.7-4bit` (352.8B, 198 GB — `glm4_moe`). It is the only
frontier-class (>128 GB) architecture with distributed support in the pinned
mlx-lm. Qwen3-235B (`qwen3_moe`) and Qwen3.5-397B (`qwen3_5_moe`) have **no**
shard/pipeline support upstream yet (ml-explore/mlx-lm#1138 stale since
April 2026) — recheck before every bench night; either landing would make a
strong head-to-head candidate.

## One-time prep (BEFORE the first plug night — no cable needed)

1. **Enable RDMA on BOTH Macs** (physical presence required): boot into macOS
   Recovery → Utilities → Terminal → `rdma_ctl enable` → reboot. Verify from
   normal boot: `ibv_devices` lists `rdma_enX` devices.
2. **Confirm weights on both Macs**: the `dev.mlx-night.prefetch` agent
   downloads the night model into `$HF_HOME` on each host (retry-until-
   complete). `hf download mlx-community/GLM-4.7-4bit` resumes manually if
   needed; mirroring the workstation's cache over the second TB cable beats
   re-downloading 198 GB.
3. **Dry-run the worker quiesce WITHOUT a cable**: run `night-quiesce`, then
   assert the agent table matches the allowlist
   (`launchctl list | grep -v com.apple`), then `night-restore` and confirm
   the recorded agents return.
4. **Check the fabric config is live**: rebuild both Macs; confirm
   `launchctl print gui/$UID/dev.mlx-night.watcher` exists on both and the
   rank agent is idle (link down → watcher no-ops).

## Plug night checklist (execution only — zero code)

1. Assign the link IPs once (System Settings or `networksetup -setmanual` on
   the Thunderbolt interface; the module defaults are
   `programs.mlx.nightCluster.linkIps`). Make sure the RDMA interface is NOT
   a member of the Thunderbolt bridge (remove it from bridge0 in System
   Settings; RDMA requires the bridge disabled on that link).
2. Cable #1 in (the RDMA rail). Verify: `ibv_devices` shows the device on
   both; note the real device name and correct
   `programs.mlx.nightCluster.rdmaDevice` if it differs from `rdma_en2` —
   the `MLX_IBV_DEVICES` matrix ships UNVALIDATED until this step. Optionally
   run `mlx.distributed_config --over thunderbolt --backend jaccl --hosts …`
   to cross-check the generated hostfile against the module's env contract.
3. JACCL hello-world: `mlx.launch --backend jaccl --hostfile <generated> --
   python -c 'import mlx.core as mx; print(mx.distributed.init().rank())'`
   (or watch the two rank logs — the watcher will have started the ranks
   as soon as the peer ping succeeded).
4. Watch the seam: `night-watcher.log` on both Macs shows
   `down -> up` → day models unload (coordinator) / quiesce sweep (worker) →
   rank kickstart. First token can take minutes (198 GB load).
5. Smoke the endpoint through the gate:
   `curl -H "Authorization: Bearer $TOKEN" https://<serving-host>:11440/v1/models`.
6. Flip the router: set `ai_night_brain_enabled: true` (+ `ai_night_model`,
   `ai_night_context_window`, and the `llm_night_api` port constant in the
   tofu registry), converge the routers. Large phase now serves `ai-default`
   on the night brain with the solo 80B as automatic fallback.
7. Bench: two runs on the night model (verdict-maturity rule: results stay
   PROVISIONAL until ≥4 runs / ≥5 days). Then let Hermes's overnight digest
   run on it.
8. **Unplug test before bed is optional but recommended**: yank the cable —
   in-flight generations abort, LiteLLM falls back to the solo brain, the
   watcher stops the rank and re-warms day serving. Surprise-yank and
   graceful shutdown converge on the same code path; there is no hardware or
   filesystem risk (each Mac's memory is its own).

## Morning

Pull the cable (glance that no generation is mid-stream if you care about
it finishing). Everything reverses unattended: ranks exit, day workers
restart and re-warm, the worker's booted-out agents bootstrap back, the
12:00 UTC flip proceeds as always. GUI apps stay closed.

## Second cable

A 2-node JACCL cluster is fully connected with ONE cable. Cable #2 is the
control/mirror rail (plain TB bridge IP link: HF-cache sync, health checks,
monitoring) and the tested spare — the cable is the single physical failure
point of the whole design. Whether JACCL uses a second link between the same
pair is expected to be "no"; test once and record the result here.

## Observability

- `in_night_logs` ships rank/watcher/prefetch logs; the gate's
  `night-access.json` rides the existing gate input (both → index=llm).
- Saved searches (ansible-splunk): night-rank crash/JACCL-error detector;
  "night mode active but no night-brain tokens in 30 min"; worker
  quiesce-violation (unexpected agent during the night window).
- The memory-headroom alert and verdict-maturity benchmarking extend to the
  night brain unchanged.
