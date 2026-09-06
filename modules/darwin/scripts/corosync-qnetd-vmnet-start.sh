#!/usr/bin/env bash
# corosync-qnetd-vmnet-start — foreground bridged socket_vmnet, supervised by
# launchd. Gives the Lima guest (started by corosync-qnetd-vm-start.sh) a real
# LAN-facing bridge on $1, so the guest's DHCP-assigned address is directly
# reachable from other LAN hosts — no port-forward, no NAT, no macOS
# Application Firewall rule (bridged traffic never enters the host's own IP
# stack, so ALF's per-binary allow-list is irrelevant here; see
# corosync-qnetd-arbiter.md).
#
# socket_vmnet must run as root: vmnet.framework calls require either the
# com.apple.vm.networking entitlement (Apple-restricted, contract-only) or
# root. This LaunchDaemon already runs as root, so no sudoers/setuid dance is
# needed — see https://github.com/lima-vm/socket_vmnet/blob/master/README.md.
#
# Runs socket_vmnet itself in the foreground so launchd KeepAlive supervises
# the real process (a crash exits this script, which launchd restarts).
#
# `pkgs.writeShellApplication` wraps this in `set -euo pipefail` and lints it.

: "${SOCKET_VMNET_BIN:?SOCKET_VMNET_BIN must be set}"
: "${VMNET_INTERFACE:?VMNET_INTERFACE must be set}"
: "${VMNET_SOCKET_PATH:?VMNET_SOCKET_PATH must be set}"

mkdir -p "$(dirname "$VMNET_SOCKET_PATH")"
rm -f "$VMNET_SOCKET_PATH"

exec "$SOCKET_VMNET_BIN" --vmnet-mode=bridged --vmnet-interface="$VMNET_INTERFACE" "$VMNET_SOCKET_PATH"
