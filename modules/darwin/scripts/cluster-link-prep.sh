# shellcheck shell=bash
# Cluster-link activation prep — concatenated into system.activationScripts.
# postActivation (runs as root at boot + rebuild). NOT wrapped in `set -e`:
# every step is intentionally non-fatal so a missing RDMA device or absent
# network service never blocks system activation.
#
# Gated on an ACTIVE RDMA link: all prep (disabling the bridge0 network
# service, detaching the port, enabling IPv6) happens ONLY when an
# RDMA-capable Thunderbolt port both exists and reports `status: active`
# (i.e. a peer is cabled in). With no active cluster cable this is a clean
# no-op and the Thunderbolt Bridge service is left ENABLED so ordinary
# (non-cluster) Thunderbolt networking keeps working.

# Find the first active RDMA-capable Thunderbolt port (the cabled port), the
# same way the converge daemon does. Absent ibv tooling or no active port
# leaves iface empty → the whole prep block below is skipped.
iface=""
if [ -x /usr/bin/ibv_devices ]; then
  for rdma_dev in $(/usr/bin/ibv_devices 2>/dev/null | /usr/bin/awk 'NR>2 {print $1}'); do
    cand="${rdma_dev#rdma_}"
    if /sbin/ifconfig "$cand" 2>/dev/null | /usr/bin/grep -q "status: active"; then
      iface="$cand"
      break
    fi
  done
fi

if [ -z "$iface" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] No active RDMA Thunderbolt link; leaving Thunderbolt Bridge enabled, skipping link prep"
else
  # Root cause of the flapping RDMA link: macOS keeps re-enslaving the cabled
  # Thunderbolt port into the "Thunderbolt Bridge" network service (device
  # bridge0), which silently undoes the runtime `bridge0 deletem` below.
  # Disable that service so macOS stops auto-adding the port to the bridge.
  # The service name is derived from its device (bridge0) via networksetup
  # rather than hardcoded, since the display name is localisable.
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Active RDMA link on $iface; disabling the bridge0 network service to stop re-enslavement..."
  svc=$(/usr/sbin/networksetup -listnetworkserviceorder | /usr/bin/awk '/Device: bridge0\)/{print prev} {sub(/^\([0-9]+\) /,""); prev=$0}')
  if [ -n "$svc" ]; then
    if /usr/sbin/networksetup -setnetworkserviceenabled "$svc" off 2>/dev/null; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Disabled network service '$svc' (device bridge0)"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to disable network service '$svc'" >&2
    fi
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] No network service maps to bridge0; nothing to disable"
  fi

  # Keep the active RDMA port out of bridge0 (RDMA needs exclusive L2) and give
  # it IPv6 link-local. The converge daemon assigns the role IPv4 address.
  if /sbin/ifconfig bridge0 2>/dev/null | /usr/bin/grep -q "member: $iface "; then
    if /sbin/ifconfig bridge0 deletem "$iface"; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Removed $iface from bridge0"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to remove $iface from bridge0" >&2
    fi
  fi
  if /usr/sbin/ipconfig set "$iface" AUTOMATIC-V6 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] IPv6 link-local enabled on $iface"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to enable IPv6 on $iface" >&2
  fi
fi
