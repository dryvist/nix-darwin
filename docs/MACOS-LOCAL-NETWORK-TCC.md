# macOS Local Network privacy: why python fails where curl succeeds

`curl` reaches a host on this Mac's subnet. `python3` — and therefore ansible,
node, and every other non-Apple binary — gets `[Errno 65] No route to host` for
the **same host and port in the same second**. Nothing is down.

## What macOS is doing

macOS gates connections whose destination sits inside the prefix of one of this
Mac's own interfaces, and exempts anything that needs a router hop. The verdict
attaches to the **responsible GUI app**, and every process it spawns inherits it.

| Context | Same-subnet peers |
| --- | --- |
| **Terminal.app** (Apple system app) | **allowed — exempt by design** |
| Apple platform binaries (`/usr/bin/curl`, `nc`, `ping`) | allowed |
| root, launchd daemons, code invoked over SSH | allowed |
| Ghostty, iTerm2, WezTerm, Kitty, VS Code terminal | **blocked without a grant** |

The gateway is carved out, and every routed subnet is unaffected. That is the
diagnostic tell: *some* hosts work and others do not, split exactly along
"is it on my subnet".

Apple's model here is device discovery on an untrusted segment — a café or hotel
LAN — not network segmentation. A homelab is indistinguishable from that, which
is why the behaviour feels arbitrary on a network you own.

## Diagnose it

```sh
python3 -c "import socket;socket.create_connection(('<host>',443),5);print('OK')"
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 -k "https://<host>/"
```

Python failing while curl returns a status is conclusive. Confirm the scope by
probing the gateway and a host on any routed subnet — both should succeed.

## Fix it, in order of preference

1. **Run it under Terminal.app.** Exempt by design, so there is no grant to
   make and nothing to revert. To dispatch one command from another terminal:

   ```sh
   osascript -e 'tell application "Terminal" to do script "<cmd> > /tmp/out 2>&1"'
   ```

2. **Put the machine on a routed segment.** The homelab admin VLAN exists for
   this: every service becomes a routed destination and the gate never engages.
   This is the durable fix, and it covers every app, not one terminal.

3. **Grant the terminal Local Network access** in System Settings → Privacy &
   Security → Local Network. Historically this did not survive, because the app
   was installed by nixpkgs `copyApps` and activation replaced the bundle on
   every `darwin-rebuild` — a replaced bundle is a new app to TCC, so the grant
   was discarded each rebuild. Casks fixed that (2026-07-29). It is still lost
   on every cask upgrade, since `greedy` replaces the bundle again.

## What will not work

- There is **no MDM payload** and **no `tccutil` verb** for Local Network, so
  this repo cannot grant or reset it. Do not add a module that claims to.
- A `/32` host route via the gateway does not help. On-link status comes from
  the interface prefix, so the destination stays on-link regardless of routes.
- Do not respond to this by disabling a safety check in whatever tool surfaced
  it — the tool is reporting a real failure to reach a real host.
