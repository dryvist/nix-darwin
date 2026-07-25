# Cluster resumption — readiness assessment

Prepared 2026-07-24 from read-only inspection of both Macs. **Nothing here was
executed**: no host was rebuilt, restarted, re-cabled, and no model was loaded
or unloaded.

Companion to [CLUSTER-RESUMPTION-DRILL.md](CLUSTER-RESUMPTION-DRILL.md), the
execution runbook. Read this one first — it establishes what is actually
running on each Mac, which guards are real versus inert, and which failure
modes are proven versus assumed. The drill's abort conditions come from the
tables below. Architecture lives in [CLUSTER_MODE.md](CLUSTER_MODE.md).

## 1. Verified state, 2026-07-24

Both hosts inspected read-only. Nothing was started, stopped, or rebuilt.

| Fact | Coordinator (`jevans-ms`) | Worker (`jevans-mbp`) |
| --- | --- | --- |
| Cable | **Out** — every Thunderbolt `en*` reports `status: inactive` | **Out** — same |
| Watcher agent | loaded, idle (`dev.mlx-cluster.watcher`, last exit 0) | loaded, idle |
| Rank agent | loaded, **not running** (`dev.mlx-cluster.rank`, PID `-`) | loaded, not running |
| Link-state file | `down` | `down` |
| Standalone serving | llama-swap running, gate bound on `:11434` and `:11440` | llama-swap running on loopback `:11434` |
| Resident model | ~16.8 GB python worker (the Coder-30B) | ~5.3 GB python worker (the 9B swap tier) |
| `iogpu.wired_limit_mb` | `102400` | `102400` |
| Swap used | 598 MB | **4281 MB** |
| Cluster weights | 104 GB present on the HuggingFace volume | 104 GB present |
| RDMA | `rdma_ctl status` → `enabled`; `ibv_devices` lists `rdma_en2`..`rdma_en5` | enabled |
| Last cluster activity | 2026-07-19 22:46 | same session |

Commands that produced this (safe to re-run — all read-only):

```sh
launchctl list | grep -iE 'mlx|cluster'
launchctl print "gui/$(id -u)/dev.mlx-cluster.watcher" | grep -iE 'CLUSTER|WIRED'
cat "$HOME/Library/Application Support/mlx-cluster/link-state"
for i in $(ifconfig -l); do ifconfig "$i" | grep -q 'status: active' && echo "$i up"; done
sysctl iogpu.wired_limit_mb vm.swapusage
lsof -nP -iTCP -sTCP:LISTEN | grep -E '1143|1144'
ps -Ao rss,pid,comm | sort -rn | head
tail -20 "$HOME/Library/Logs/mlx-cluster/cluster-watcher.log"
```

**Summary in one line:** both hosts are cabled-out, serving standalone, with
clustered mode fully enabled in config and every cluster agent loaded and
waiting. Plugging the cable in is the only action needed to start a rank.

## 2. Enabled versus inert — read this before trusting any guard

Everything in `programs.mlx.clusterMode` is genuinely enabled on both hosts
(`enable = true`, role coordinator/worker, `modelCatalogKey = "glm47-reap50"`).
One thing that reads as an active guard is not one.

### The wired ceiling no longer changes at link-up

[CLUSTER_MODE.md](CLUSTER_MODE.md) and
[FIRST-PLUG-VALIDATION.md](FIRST-PLUG-VALIDATION.md) describe the mitigation as
"90000 MB coordinator / 80000 MB worker". **That is stale.** It was superseded
on 2026-07-19 in `hosts/common/default.nix`, which now sets:

```nix
clusterWiredLimitMb = config.system.appleSiliconTunables.wiredLimitMb;
```

Both hosts derive `maxLocalLlmGb = 100`, so the clustered and standalone
ceilings are the **same number** — confirmed live in the worker's watcher
environment and in the emitted sudoers grant, which deduplicates to a single
line:

```text
CLUSTER_WIRED_LIMIT_MB => 102400
CLUSTER_STANDALONE_WIRED_LIMIT_MB => 102400

# /etc/sudoers.d/cluster-wired-limit
jevans ALL=(ALL) NOPASSWD: /usr/sbin/sysctl -w iogpu.wired_limit_mb=102400
```

Three consequences the drill must account for:

1. `set_wired_limit` returns success immediately when current equals target,
   so **no sysctl write happens** at link-up or link-down.
2. The pre-start interlock in the watcher — *"wired ceiling not applied; NOT
   starting the rank"* — can therefore **never fire**. There is no longer a
   ceiling gate in front of a rank start.
3. The drill **cannot prove the ceiling restore path works**, because
   `cluster-detach`'s `ceiling_restored()` check compares the live value
   against the standalone value and both are already 102400. That assertion
   passes trivially. Do not record it as evidence.

This is a deliberate decision, not a bug: the 2026-07-19 commit argues that a
low cap forced swap thrash, and that swap saturation kills a cluster as surely
as a wired-out WindowServer. The real protections today are the ~28 GiB OS
reserve baked into the 100 GiB ceiling, the worker's GUI quiesce, and the
swap gates in `cluster-join` / `cluster-detach`. **The runbook plans around
those, not around a ceiling flip.**

### The readiness latch is one-shot on both ranks

The coordinator probes `/v1/models` until it answers once, then touches
`rank-ready` and never probes again. The worker has no readiness or liveness
check at all. Only launchd `state = running` is re-evaluated per tick. A rank
that wedges mid-generation is invisible to the watcher indefinitely — the
hung-init grace timer lives in the `else` branch of the readiness probe, so it
applies only *before* readiness.

## 3. Failure modes by transition

"Proven" means observed in a log or live state on these machines. "Assumed"
means the code path exists and reads correct but has not been seen to run here.

### Link-up

| Failure | What the config does | Status |
| --- | --- | --- |
| Shard load starves WindowServer | No ceiling change (§2); the 28 GiB reserve and the GUI quiesce are the guards | **Assumed.** The panic predates both |
| Rank crash-loops, burning RDMA protection domains | Cap of 3 kickstarts, then halt + alert; PD exhaustion is reboot-only | Assumed — cap never hit here |
| Rank hangs inside distributed init | Restarted after `CLUSTER_LOAD_GRACE_SECS` (1800 s), pre-readiness only | Assumed |
| Boot with cable in skips the quiesce | Fixed: quiesce runs before *every* kickstart, not just on the down→up edge | Assumed — never tested |
| Loading a shard against stale swap | `cluster-join` refuses above 8000 MB swap used | Assumed |

### Steady clustered serving

| Failure | What the config does | Status |
| --- | --- | --- |
| `/v1/models` answers but completions wedge | **Nothing.** Readiness is latched; no post-ready health check exists | **Proven to happen.** See below |
| Multi-request pipeline hang | `--prompt-cache-size 0` is wired on both ranks as a live experiment (INC-17070) | Mitigation unproven |

The 2026-07-19 watcher log is the important evidence. In the final session the
rank reached readiness and then fired its 1-token warm generation **twice
without ever succeeding** (each attempt carries a 300 s curl timeout), until
the link went down:

```text
cluster-link: down -> up (coordinator)
cluster-link: rank not running; kickstarting (attempt 1)
cluster-link: rank ready (:11440 answering)
cluster-link: rank ready; firing 1-token warm generation
cluster-link: rank ready; firing 1-token warm generation
cluster-link: up -> down (coordinator); restoring normal serving
```

The matching rank log shows `GET /v1/models 200` at 22:46 and **no** completion
after it. An earlier cycle the same day did serve
`POST /v1/chat/completions 200`, so the wedge is intermittent, not total.

### Link-down

| Failure | What the config does | Status |
| --- | --- | --- |
| Rank keeps running | Watcher SIGTERMs it on the up→down edge; `cluster-detach` escalates to SIGKILL | Partly proven — `up -> down` edges are in the log |
| Ceiling not restored | No-op today (§2) | Untestable as configured |
| Coordinator preload not re-warmed | Watcher kickstarts the warmup one-shot: one 1-token completion per `preload` entry | **Assumed, known hole** |
| Worker agents not restored | Watcher runs `cluster-restore`, bootstrapping exactly the recorded set | Assumed |

The re-warm hole (INC-17071): the warmup one-shot talks to llama-swap over
loopback. If the standalone **server** agent is not loaded, the warmup
kickstart hits nothing and silently no-ops. The watcher never bootstraps the
server agent — only `cluster-detach` does. On the coordinator the watcher only
*unloads models* and leaves the proxy up, so the plain unplug path is expected
to work; but if a session ever ran `cluster-join` (which boots the server agent
out), a bare cable-yank will **not** bring serving back. Use `cluster-detach`.

### Unplanned peer loss

| Event | Behavior | Status |
| --- | --- | --- |
| Cable yanked mid-inference | Identical to graceful unplug — one failed ping flips the state, within 30 s. In-flight generations abort | Assumed |
| Peer sleeps or reboots | Same path; ping fails, teardown runs | Assumed |
| Watcher itself not running | **Nothing restores.** No teardown, no re-warm, ceiling frozen wherever it was | Assumed |
| Rank SIGKILLed (not SIGTERM) | Wired shard memory likely leaked; `cluster-detach` exits 3 and demands a reboot before the next join | Assumed |

A failed restore is swallowed (`|| true`) and the state file is written
unconditionally, so the up→down edge is consumed. **There is no retry.**
Fixed in nix-ai#1384 along with the re-warm hole and the missing post-readiness
escalation — unverified until the drill runs, and not yet converged onto either
Mac, so the behavior described above is still what these machines do today.

## 4. Recording the outcome

After running [CLUSTER-RESUMPTION-DRILL.md](CLUSTER-RESUMPTION-DRILL.md),
update [FIRST-PLUG-VALIDATION.md](FIRST-PLUG-VALIDATION.md): tick **link-down
restore**, **unplug test**, and (if you reboot with the cable in)
**reboot-with-cable-in**, with the observed evidence rather than a bare check.

If Phase 4's second request wedges, that is the INC-17070 reproduction, and the
`--prompt-cache-size 0` experiment in `hosts/common/cluster-wired-limit.nix`
should be reconsidered rather than left in place silently.
