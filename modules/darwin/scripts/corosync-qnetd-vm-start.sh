#!/usr/bin/env bash
# corosync-qnetd-vm-start — create (if needed) and start the corosync-qnetd
# Lima guest, then block in a poll loop so launchd can supervise it.
#
# `limactl start` daemonizes the guest's QEMU process and returns, so there is
# no single foreground process for launchd's KeepAlive to watch. This loop is
# that supervisor: it polls `limactl list` and exits non-zero the moment the
# instance is no longer Running, so launchd (KeepAlive = true) restarts this
# script, which restarts the guest.
# ponytail: polling, not an event-driven watch — Lima has no "wait for stop"
# primitive; upgrade to `limactl` event streaming if it ever ships one.
#
# LIMA_HOME is set by the caller (the LaunchDaemon's EnvironmentVariables) to
# a root-writable directory — Lima's default $HOME/.lima assumes an
# interactive user session, which a boot-time root LaunchDaemon does not have.
#
# `pkgs.writeShellApplication` wraps this in `set -euo pipefail` and lints it.

: "${LIMACTL_BIN:?LIMACTL_BIN must be set}"
: "${LIMA_INSTANCE:?LIMA_INSTANCE must be set}"
: "${LIMA_YAML_PATH:?LIMA_YAML_PATH must be set}"
: "${LIMA_HOME:?LIMA_HOME must be set}"
export LIMA_HOME

mkdir -p "$LIMA_HOME"

if ! "$LIMACTL_BIN" list --quiet | grep -qx "$LIMA_INSTANCE"; then
  "$LIMACTL_BIN" create --name="$LIMA_INSTANCE" --tty=false "$LIMA_YAML_PATH"
fi

"$LIMACTL_BIN" start --tty=false "$LIMA_INSTANCE"

trap '"$LIMACTL_BIN" stop "$LIMA_INSTANCE" >/dev/null 2>&1 || true' TERM INT

while status=$("$LIMACTL_BIN" list --format '{{.Status}}' "$LIMA_INSTANCE" 2>/dev/null); do
  [ "$status" = "Running" ] || exit 1
  sleep 15
done
exit 1
