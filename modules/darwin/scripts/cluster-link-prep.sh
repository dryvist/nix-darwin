# shellcheck shell=bash
# Cluster-link prep (root, boot + rebuild) — static Thunderbolt link config.
#
# One idempotent pass, persisted by macOS SystemConfiguration — no runtime
# daemon. Disables the Thunderbolt Bridge network service (macOS otherwise
# keeps enslaving Thunderbolt ports into bridge0, breaking the exclusive L2
# that Apple RDMA needs), puts the SAME manual role IPv4 on every physical
# Thunderbolt port's network service (only one port is ever cabled to the
# peer; inactive services install no routes), and sweeps any residual
# Thunderbolt member out of bridge0.
#
# Consumed environment:
#   CLUSTER_LINK_IP   this host's link address (role-derived synthetic)

: "${CLUSTER_LINK_IP:?CLUSTER_LINK_IP must be set}"

prefix="[cluster-link-prep]"
order="$(/usr/sbin/networksetup -listnetworkserviceorder)"

# 1. Thunderbolt Bridge network service off. The service name is derived
#    from its device (bridge0) since the display name is localisable.
bridge_svc="$(printf '%s\n' "$order" \
  | /usr/bin/awk '/Device: bridge0\)/{print prev; exit} {sub(/^\([0-9*]+\) /,""); prev=$0}')"
if [ -n "$bridge_svc" ]; then
  if /usr/sbin/networksetup -setnetworkserviceenabled "$bridge_svc" off 2>/dev/null; then
    echo "$prefix disabled network service '$bridge_svc' (device bridge0)"
  else
    echo "$prefix WARN failed to disable network service '$bridge_svc'" >&2
  fi
fi

# 1.2 Sweep Thunderbolt members out of bridge0 BEFORE creating services:
#     SystemConfiguration refuses -createnetworkservice on an enslaved port
#     ("Unable to access the System Configuration database" — observed
#     2026-07-18 as root). Devices come from -listallhardwareports, never the
#     service order: with no per-port services the service order has no
#     Thunderbolt lines at all, which is exactly the state being repaired
#     (the old sweep read the service order and so swept nothing, ever).
while IFS= read -r tb_dev; do
  [ -n "$tb_dev" ] || continue
  if /sbin/ifconfig bridge0 2>/dev/null | /usr/bin/grep -q "member: $tb_dev "; then
    if /sbin/ifconfig bridge0 deletem "$tb_dev" 2>/dev/null; then
      echo "$prefix removed $tb_dev from bridge0"
    else
      echo "$prefix WARN failed to remove $tb_dev from bridge0" >&2
    fi
  fi
done < <(/usr/sbin/networksetup -listallhardwareports \
  | /usr/bin/awk '/^Hardware Port: Thunderbolt [0-9]/{getline; sub(/^Device: /, ""); print}')

# 2. Same link IPv4 directly on every physical Thunderbolt DEVICE via
#    ifconfig — deliberately NOT SystemConfiguration services: on macOS 26,
#    `networksetup -createnetworkservice` fails as root with "Unable to
#    access the System Configuration database" even for un-enslaved ports
#    (verified 2026-07-18), so per-port services cannot be created at all on
#    hosts that never had them. Persistence comes from this prep rerunning at
#    every boot + rebuild (root postActivation), which is the module's
#    existing contract. Only one port is ever cabled; un-cabled ports have no
#    carrier, so the shared address is inert on them.
while IFS= read -r tb_dev; do
  [ -n "$tb_dev" ] || continue
  if /sbin/ifconfig "$tb_dev" 2>/dev/null | /usr/bin/grep -q "inet $CLUSTER_LINK_IP "; then
    continue
  fi
  if /sbin/ifconfig "$tb_dev" inet "$CLUSTER_LINK_IP" netmask 255.255.255.0 alias 2>/dev/null; then
    echo "$prefix set $CLUSTER_LINK_IP on $tb_dev"
  else
    echo "$prefix WARN failed to set $CLUSTER_LINK_IP on $tb_dev" >&2
  fi
done < <(/usr/sbin/networksetup -listallhardwareports \
  | /usr/bin/awk '/^Hardware Port: Thunderbolt [0-9]/{getline; sub(/^Device: /, ""); print}')
