# Cluster resumption drill — plug/unplug acceptance test

Prepared 2026-07-24 from live inspection of both Macs. **Nothing in this
document has been executed.** It exists to be run once, supervised, with a
hand on the cable.

Acceptance bar this drill closes:

> Link-up brings the cluster shard online under its wired ceiling; link-down
> degrades cleanly to single-host serving and re-warms the preload list with
> no manual step; neither host starves WindowServer. Proven by plugging and
> unplugging the link and showing serving survives both transitions.

It closes three unchecked boxes in
[FIRST-PLUG-VALIDATION.md](FIRST-PLUG-VALIDATION.md): **link-down restore**,
**unplug test**, and **reboot-with-cable-in**. Read
[CLUSTER_MODE.md](CLUSTER_MODE.md) first for the architecture; this file is
execution only.

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

## 4. The drill

Two people-minutes of cable handling; budget 60–90 minutes wall-clock, most of
it shard load. Run every command from the **worker** in a Ghostty window
(Ghostty is on the quiesce terminal allowlist) with a second SSH session open
to the coordinator.

### Phase 0 — pre-flight (no cable, ~5 min)

```sh
# Both hosts. All four must hold before the cable goes in.
sysctl vm.swapusage                       # used must be < 8000 MB (join gate)
sysctl iogpu.wired_limit_mb               # expect 102400
cat "$HOME/Library/Application Support/mlx-cluster/link-state"   # expect: down
launchctl print "gui/$(id -u)/dev.mlx-cluster.watcher" >/dev/null && echo watcher-ok
```

**Closes when:** swap used is under 8000 MB on both hosts, both report
`down`, and both watchers print. The worker was at 4281 MB on 2026-07-24 —
only ~3.7 GB of margin. **If the worker is above 8000 MB, reboot it before
starting.** That is the documented INC-17075 doctrine, not a suggestion.

Record the baseline you will compare against at the end:

```sh
ps -Ao rss,pid,comm | sort -rn | head -5 > /tmp/drill-baseline-$(hostname -s).txt
memory_pressure -Q | grep -i percentage
```

### Phase 1 — accept the worker blast radius

`cluster-quiesce` runs automatically at link-up on the worker. On this machine
it will quit every non-terminal GUI app and boot out **11 user agents**,
recording them for restore. Enumerate them first so nothing is a surprise:

```sh
keep='^(com\.apple\.|org\.nix-community\.|com\.nix-darwin\.|dev\.mlx-cluster\.|org\.git-scm\.|com\.openssh\.)|^dev\.mlx-model-server\.logrotate$'
for p in "$HOME/Library/LaunchAgents/"*.plist; do
  l=$(basename "$p" .plist); [[ "$l" =~ $keep ]] || echo "SWEEP: $l"
done
```

As of 2026-07-24 that set includes the standalone MLX server and its warmup,
four 24/7 capture agents, a tmux session supervisor, and three third-party
updaters. Two matter:

- **`dev.local.tmux-cc-session`** — if you are driving this drill from a tmux
  session under that agent, quiesce boots out its supervisor. Run the drill
  from a plain Ghostty window instead.
- **The 24/7 capture agents** stop for the whole cluster window. Expect a
  recording gap; they come back at restore.

The always-on 9B helper process has **no** user LaunchAgent plist and is not a
foreground GUI app, so quiesce does not touch it. It keeps ~1.2 GB resident on
the worker throughout the cluster window. Budget for it.

**Closes when:** you have read the sweep list and accepted it.

### Phase 2 — link-up

Plug the Thunderbolt cable in. Then, on both hosts:

```sh
# 1. Link carrier — one of the Thunderbolt ports goes active within seconds
for i in $(ifconfig -l); do ifconfig "$i" | grep -q 'status: active' && echo "$i UP"; done

# 2. Peer reachable over the link (this is exactly what the watcher tests)
ping -c 1 -t 2 "$CLUSTER_STATIC_PEER_IP"     # from the watcher env, do not hardcode

# 3. Watch the state machine (both hosts, leave running)
tail -f "$HOME/Library/Logs/mlx-cluster/cluster-watcher.log"
```

Expect within one 30 s tick: `down -> up`, then `rank not running;
kickstarting (attempt 1)`.

**Closes when:** the rank agent shows `state = running` on **both** hosts:

```sh
launchctl print "gui/$(id -u)/dev.mlx-cluster.rank" | grep 'state ='
```

### Phase 3 — shard load under memory watch

This is the dangerous window. Poll every 30 s on **both** hosts:

```sh
while true; do
  printf '%s pressure=%s swap=%s wired=%s\n' "$(date +%T)" \
    "$(memory_pressure -Q | awk '/percentage/{print $NF}')" \
    "$(sysctl -n vm.swapusage | awk '{print $6}')" \
    "$(sysctl -n iogpu.wired_limit_mb)"
  sleep 30
done
```

Also confirm the shard is actually loading rather than spinning:

```sh
ps -Ao rss,pid,comm | grep -i python | sort -rn | head -3   # RSS should climb toward ~49 GB
tail -5 "$HOME/Library/Logs/mlx-cluster/cluster-rank.error.log"
```

**Closes when:** the coordinator watcher logs
`cluster-link: rank ready (:11440 answering)` and per-rank python RSS has
settled near 49 GB on both hosts, with free memory percentage still above 20%.

Expect this to take minutes. `CLUSTER_LOAD_GRACE_SECS` is 1800 s for a reason.

### Phase 4 — prove clustered serving

The warm generation is the exact step that failed on 2026-07-19, so watch for
it explicitly:

```sh
grep -c 'firing 1-token warm generation' "$HOME/Library/Logs/mlx-cluster/cluster-watcher.log"
```

More than one occurrence **after** the most recent `rank ready` line means the
warm generation is not completing — the INC-17070 wedge. Go to the abort
condition.

Then make a real request of your own, through the gate, on the coordinator:

```sh
# Model id comes from the catalog (key glm47-reap50); read it from the live env
# rather than typing it — physical ids belong only in catalog data.
MODEL=$(launchctl print "gui/$(id -u)/dev.mlx-cluster.watcher" \
        | awk -F'=> ' '/CLUSTER_MODEL/{print $2}')

PROMPT='Reply with the single word: clustered'
BODY=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}],%s}' \
       "$MODEL" "$PROMPT" '"max_tokens":16,"stream":false,"temperature":0')

time curl -fsS -m 600 http://127.0.0.1:11440/v1/chat/completions \
  -H 'Content-Type: application/json' -d "$BODY"
```

**Closes when:** that returns a completion containing `clustered`, and a second
identical request also returns (single-request success does not prove the
multi-request path — that is the whole content of INC-17070). Record both
latencies.

Also confirm the seam is real, not a solo fallback: the worker's rank python
process must be holding ~49 GB. A coordinator answering alone means the
pipeline did not form.

### Phase 5 — link-down, the graceful path

Use the front-end, not the cable, for the first teardown. It verifies
postconditions instead of trusting logs:

```sh
cluster-detach; echo "exit=$?"
```

**Closes when:** exit is `0` and the summary reports markers clear, rank
stopped, and — on the coordinator — a real completion from the standalone
resident. Exit `3` means it worked but the node must be rebooted before the
next join. Exit `1` is a failed postcondition; stop and read the FAIL lines.

Then verify the two things the acceptance bar actually names:

```sh
# Standalone serving answers again (coordinator)
curl -fsS http://127.0.0.1:11434/v1/models | head -c 200

# Preload re-warm fired, with no manual step
log show --last 10m --predicate 'process == "launchd"' 2>/dev/null | grep -i warmup
launchctl print "gui/$(id -u)/dev.mlx-model-server.warmup" | grep -E 'state =|last exit'

# Worker agents came back — compare against the Phase 1 sweep list
launchctl list | grep -vE '^-\s+0\s+com\.apple' | head -30
```

**Closes when:** the coordinator serves a completion from its standalone
resident, the warmup one-shot shows a clean recent exit, and every label from
the Phase 1 sweep list is loaded again on the worker.

### Phase 6 — link-down, the surprise path

Only after Phase 5 passes. Re-plug, wait for `rank ready`, start a long
generation, and **pull the cable mid-stream**.

```sh
# Start a long generation in one window, yank the cable, then watch:
tail -f "$HOME/Library/Logs/mlx-cluster/cluster-watcher.log"
```

**Closes when:** within ~30 s both watchers log `up -> down`, the in-flight
request aborts client-side rather than hanging forever, `pgrep -f
'/mlx_lm\.server'` returns nothing on both hosts, and the same standalone and
agent-restore checks from Phase 5 pass **without** running `cluster-detach`.

That last clause is the whole point of Phase 6: Phase 5 proves the tool works,
Phase 6 proves the unattended path does.

### Abort condition

**Stop, pull the cable, and run `cluster-detach` on both hosts immediately if
any one of these reads true:**

| Reading | Command | Threshold |
| --- | --- | --- |
| Memory pressure | `memory_pressure -Q` | free percentage **< 10%** on either host |
| Swap growth | `sysctl -n vm.swapusage` | used **> 20000 MB**, or climbing > 2 GB per minute |
| Rank RSS overshoot | `ps -Ao rss,pid,comm \| grep python` | any rank python **> 70 GB** (shard should settle ~49 GB) |
| UI starvation | direct observation | cursor stutter, beachball, or the menu bar stops redrawing on the worker |
| Warm-generation wedge | `grep -c 'firing 1-token warm' …watcher.log` | **≥ 3** occurrences after the latest `rank ready` |
| Kickstart loop | `…watcher.log` | any `HALTING kickstarts (RDMA PD guard)` line |

The last one is special: an RDMA protection-domain leak is **reboot-only**
recovery. If you see it, detach and reboot before attempting anything else.

If the worker's UI is already unresponsive, pull the cable physically — that
is the fastest path to teardown, and the watcher will act on it within 30 s
without needing a working shell.

## 5. Blocking gaps — these need an operator

Nothing in this drill can be automated end to end. Explicitly required:

1. **Cable — physical.** Insert one Thunderbolt 5 cable between the two Macs
   (Phase 2) and remove it (Phases 5–6). There is no software substitute:
   `cluster-detach` can take the link admin-down but cannot re-establish it.
2. **Worker swap headroom.** If Phase 0 shows more than 8000 MB swap used on
   the worker, reboot it first — `sudo shutdown -r now`, interactive password.
3. **Session placement.** Start the drill from a plain Ghostty window, not a
   tmux session under `dev.local.tmux-cc-session`; quiesce boots that agent out.
4. **Accepting the recording gap.** The 24/7 capture agents stop for the whole
   cluster window. That is an operator decision, not a technical blocker.
5. **No rebuild is required.** Both hosts already run the enabled config. If a
   rebuild ever does become necessary, `darwin-rebuild switch` needs
   interactive sudo, and both hosts must land on the same generation —
   `cluster-join`'s parity preflight compares system generations against the
   remote HEAD and refuses a mismatched pair.

`sudo` inside the watcher path is already covered by the exact-value sudoers
grant and needs no interaction; `cluster-detach`'s `ifconfig … down` is
likewise granted. Neither prompts.

## 6. What to record afterwards

Update [FIRST-PLUG-VALIDATION.md](FIRST-PLUG-VALIDATION.md) — tick
**link-down restore**, **unplug test**, and (if you reboot with the cable in)
**reboot-with-cable-in**, with the observed evidence rather than a bare check.
If Phase 4's second request wedges, that is the INC-17070 reproduction and the
`--prompt-cache-size 0` experiment in `hosts/common/cluster-wired-limit.nix`
should be reconsidered rather than left in place silently.
