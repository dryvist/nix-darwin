# LaunchDaemon self-heal

Critical KeepAlive daemons (Cribl Edge, firewall-log-shipping) are kept running
automatically after every activation. This document explains the failure mode
it prevents and the manual recovery to use if you ever hit it before the fix is
deployed.

## The failure mode: launchd's penalty box

launchd throttles a KeepAlive daemon that crashes repeatedly in quick
succession. After enough fast failures it stops respawning the daemon and parks
it in a "penalty box": `launchctl print system/<label>` still succeeds and shows

```text
state = spawn scheduled
```

with **no `pid` line** and a stale `runs` count. The daemon is *loaded but not
running*, and launchd will not restart it on its own.

nix-darwin only (re)starts a daemon when its plist **content** changes. A
penalty-boxed daemon keeps its unchanged plist, so `darwin-rebuild switch` walks
right past it — the daemon stays dead and whatever it ships (here: all
Mac-origin Splunk telemetry) goes dark silently, for days if unnoticed.

`launchd-bootstrap.nix` does not cover this case either. It only bootstraps
daemons whose `launchctl print` **fails** (never-loaded); a penalty-boxed daemon
is loaded, so it is skipped. It also globs only `org.nixos.*` /
`com.nix-darwin.*` plists, so a daemon labelled `com.<user>.*` (e.g.
`com.jevans.firewall-log-shipping`) is invisible to it.

## The automated fix

`modules/darwin/launchd-self-heal.nix` runs in `postActivation` (after
nix-darwin's launchd reconcile). For each registered critical daemon it checks
whether the daemon is running and, if not, force-reloads it:

```bash
launchctl bootout   system/<label>          # clears the penalty box
launchctl bootstrap system /Library/LaunchDaemons/<label>.plist   # starts fresh
```

Running daemons (those with a `pid` line) are left untouched, so the step is
idempotent — it acts only on a dead daemon.

### Registering a daemon

A daemon opts in next to its own definition, so a rename can't silently drop
coverage:

```nix
services.launchdSelfHeal.labels = [ "com.nix-darwin.cribl-edge" ];
```

Currently registered: `com.nix-darwin.cribl-edge` (Cribl Edge, in
`apps/cribl-edge.nix`) and `com.<user>.firewall-log-shipping` (in `logging.nix`).
Add a label only for a **KeepAlive** daemon that must always be running;
registering a one-shot daemon would make every activation needlessly restart it.

## Manual recovery

If a daemon is wedged and you need it up before the next activation:

```bash
sudo launchctl bootout   system/<label>
sudo launchctl bootstrap system /Library/LaunchDaemons/<label>.plist
launchctl print system/<label> | grep -E 'state =|pid =|last exit'   # verify
```

A healthy result shows `state = running`, a numeric `pid`, and
`last exit code = (never exited)`.

### Do NOT use `launchctl kickstart`

`launchctl kickstart -k system/<label>` **hangs indefinitely** on a
penalty-boxed daemon — it blocks waiting on a spawn launchd will not perform,
and `runs` never increments. Use `bootout` + `bootstrap` (which also kills any
hung `kickstart` still waiting on that label), or reboot: a fresh launchd wipes
the in-memory penalty box and `RunAtLoad` brings the daemon back.

## See also

- `modules/darwin/launchd-self-heal.nix` — the mechanism
- `modules/darwin/launchd-bootstrap.nix` — bootstraps never-loaded nix daemons
- `docs/ACTIVATION-SCRIPTS-RULES.md` — activation-script constraints this obeys
