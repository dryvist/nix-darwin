# corosync-qnetd arbiter

`programs.corosync-qnetd-arbiter` runs a [corosync-qnetd][qnetd] quorum
arbiter for the Proxmox cluster, as a Lima Linux VM supervised by two
LaunchDaemons. It is a fifth vote available to a 4-node cluster: with it
reachable, the cluster survives two node losses instead of one, and a cold
boot can reach quorum with two nodes instead of waiting for every node.

## Why not Apple's `container` tool

`container-apiserver` runs as a per-user LaunchAgent, so it dies at logout;
boot-time autostart with no login is an open, unimplemented upstream request;
and there is a known unresolved bug where its networking silently breaks
after a system restart. An arbiter that quietly stops being reachable after
every reboot is worse than none — the failure is invisible until the moment
it is needed. `modules/darwin/apps/apple-container-runtime.nix` documents the
same per-user constraint for its own (different) use case.

## Networking mode: bridged, via a pre-started `socket_vmnet`

corosync-qnetd only ever accepts inbound connections on TCP 5403 — it never
initiates one — so the requirement is simply that the port be reachable from
other LAN hosts.

Two Lima networking modes were available:

- **user-v2 (default, NAT/slirp)**: the guest gets a private, host-only
  address; reaching a guest port from another LAN host needs an explicit
  host-side port forward, which Lima does not expose for inbound traffic
  from outside the host.
- **bridged (chosen)**: the guest attaches directly to the physical LAN
  segment (via `socket_vmnet --vmnet-mode=bridged`) and gets its own
  DHCP-assigned address on that segment — reachable from any other LAN host
  exactly like a physical machine, no port forward needed.

`socket_vmnet` must run as root: using `vmnet.framework` requires either the
`com.apple.vm.networking` entitlement (Apple-restricted, needs a contract) or
root — see the [socket_vmnet README][socket-vmnet-readme]. Because the
LaunchDaemon (`com.nix-darwin.corosync-qnetd-vmnet`) already runs as root at
boot, no sudoers or setuid workaround is needed: the daemon starts
`socket_vmnet` directly, and the guest's `lima.yaml` points at that socket via
the instance-level `networks: - socket: <path>` field, bypassing Lima's own
sudo-based orchestration entirely.

Bridged traffic never enters the macOS host's own IP stack — it is a layer-2
bridge — so the macOS Application Firewall (which filters per-binary,
host-destined traffic) does not apply here. The guest's own firewall is what
matters: Ubuntu cloud images ship with `ufw` inactive by default, and the
provisioning script only adds an explicit `ufw allow 5403/tcp` as a guard in
case a future base image changes that default.

**Requires an on-Mac verification step not done here**: whether the nixpkgs
`qemu` build on this platform is codesigned with the HVF acceleration
entitlement could not be checked from this session's environment. If it
lacks it, Lima falls back to software emulation (TCG) — slower, but qnetd's
load is trivial, so this is a performance-only concern, not a correctness
one.

## `socket-vmnet` is vendored, not from nixpkgs

`socket-vmnet` isn't in this repo's pinned nixpkgs release branch yet (only
in the unstable channel as of 2026-09) — enabling this module against the
plain `pkgs.socket-vmnet` attribute fails to evaluate. `packages/socket-vmnet.nix`
vendors the same upstream derivation, same pattern as `packages/cribl-edge.nix`.
Drop it and switch back to `pkgs.socket-vmnet` once the pin catches up.

## Power settings: not new — already declarative

The Mac must not sleep its network. This repo already expresses that via
`modules/darwin/apps/../energy.nix`'s `system.energy` options
(`sleep.ac` defaults to `0`, i.e. never). Enabling this module on a host
that has `system.energy.enable = true` (its default settings) already
satisfies the requirement — no new `pmset` code was added here.

## Exactly one qdevice per cluster

corosync's `quorum.device` block in `corosync.conf` is a single stanza, not a
list — a cluster has room for exactly one qdevice. `enable` is a plain
per-host option so it can be set on either Mac, but **only one may be
`enable = true` at a time**. The other is a standby build: identical code,
ready to flip on if the primary host is decommissioned, never a second vote.

## Failure behaviour

If the arbiter is unreachable, its vote is simply not counted — corosync's
qdevice/votequorum documentation describes the qdevice's vote timing out
(`quorum.device.sync_timeout`, default 30s) with the cluster then evaluating
quorum from its remaining node votes ([corosync-qdevice(8)][qdevice-man];
[SUSE HA QDevice/QNetd guide][suse-qdevice]). For this cluster that means
falling back to 4 votes against quorum 3 — the exact quorum math the cluster
already runs without this module. A non-24/7 arbiter host is therefore
acceptable: on any night it is off, the cluster is no worse off than today.

## Out of scope: the Proxmox side

This module builds only the arbiter (this host). Wiring a cluster to it is a
separate change in the Proxmox-side repo:

- Install `corosync-qdevice` on every cluster node.
- Run `pvecm qdevice setup <arbiter-lan-ip>` from one node (this performs the
  cert exchange with `corosync-qnetd`; nothing pre-provisions certs here).
- The arbiter's LAN IP is whatever DHCP assigns the bridged guest — check
  `limactl shell corosync-qnetd -- ip -4 addr show lima0` after this module
  is enabled and activated.

[qnetd]: https://manpages.debian.org/corosync-qnetd
[socket-vmnet-readme]: https://github.com/lima-vm/socket_vmnet/blob/master/README.md
[qdevice-man]: https://www.systutorials.com/docs/linux/man/8-corosync-qdevice/
[suse-qdevice]: https://documentation.suse.com/sle-ha/15-SP5/html/SLE-HA-all/cha-ha-qdevice.html
