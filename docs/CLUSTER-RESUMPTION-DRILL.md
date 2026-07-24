# Cluster resumption drill — plug/unplug acceptance test

Execution only. Prepared 2026-07-24 and **not yet run** — this is a plan, not
a result.

Acceptance bar this drill closes:

> Link-up brings the cluster shard online under its wired ceiling; link-down
> degrades cleanly to single-host serving and re-warms the preload list with
> no manual step; neither host starves WindowServer. Proven by plugging and
> unplugging the link and showing serving survives both transitions.

It closes three unchecked boxes in
[FIRST-PLUG-VALIDATION.md](FIRST-PLUG-VALIDATION.md): **link-down restore**,
**unplug test**, and **reboot-with-cable-in**.

Read [CLUSTER-RESUMPTION-READINESS.md](CLUSTER-RESUMPTION-READINESS.md) before
running anything. It holds the verified state of both hosts, the guards that
are inert despite reading as active, and the failure-mode tables the abort
condition below is derived from.

## 1. The drill

Two people-minutes of cable handling; budget 60–90 minutes wall-clock, most of
it shard load. Run every command from the **worker** in a Ghostty window
(Ghostty is on the quiesce terminal allowlist) with a second SSH session open
to the coordinator.

### Phase 0 — pre-flight (~5 min)

**Reboot the worker first. This is a standing step, not a conditional one.**

```sh
sudo shutdown -r now      # on the worker, before anything else
```

Not conditional on any swap reading: the 8000 MB refusal belongs to
`cluster-join`, and the cable path this drill uses has no swap check at all.
Rebooting removes the stale-swap spiral (INC-17075) outright. Readiness §1
records the swapped-out working set this is guarding against.

Then, on both hosts once the worker is back up:

```sh
sysctl vm.swapusage
sysctl iogpu.wired_limit_mb               # expect 102400
cat "$HOME/Library/Application Support/mlx-cluster/link-state"   # expect: down
launchctl print "gui/$(id -u)/dev.mlx-cluster.watcher" >/dev/null && echo watcher-ok
```

**Closes when:** the worker has been rebooted this session, both hosts report
`down`, and both watchers print. Treat the post-reboot swap figure as a
baseline to compare against later, not as a threshold to pass.

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

"Wedged" means the same to you and to the watcher: **three consecutive
warm-generation attempts after readiness**, each bounded by a 300 s timeout —
roughly fifteen minutes. At that count the watcher (nix-ai#1384) tears the rank
down itself: halt latch, SIGTERM, ceiling and standalone serving restored, one
alert. That is not a pass — it is the abort you would have called by hand, and
Phase 5 still runs to verify the result.

**Until nix-ai#1384 is converged on both Macs none of that exists** and the
abort is entirely yours to call. Check which behavior you have first.

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
| Warm-generation wedge | `grep -c 'firing 1-token warm' …watcher.log` | **3** attempts after the latest `rank ready` — same count the watcher itself acts on |
| Kickstart loop | `…watcher.log` | any `HALTING kickstarts (RDMA PD guard)` line |

The last one is special: an RDMA protection-domain leak is **reboot-only**
recovery. If you see it, detach and reboot before attempting anything else.

If the worker's UI is already unresponsive, pull the cable physically — that
is the fastest path to teardown, and the watcher will act on it within 30 s
without needing a working shell.

## 2. Blocking gaps — these need an operator

Nothing in this drill can be automated end to end. Explicitly required:

1. **Cable — physical.** Insert one Thunderbolt 5 cable between the two Macs
   (Phase 2) and remove it (Phases 5–6). There is no software substitute:
   `cluster-detach` can take the link admin-down but cannot re-establish it.
2. **Reboot the worker.** `sudo shutdown -r now`, interactive password. A
   standing pre-drill step, not conditional on any swap reading — see Phase 0.
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

## 3. What to record afterwards

Recording the outcome belongs with the validation record, not the
runbook — see
[CLUSTER-RESUMPTION-READINESS.md](CLUSTER-RESUMPTION-READINESS.md) §4.
