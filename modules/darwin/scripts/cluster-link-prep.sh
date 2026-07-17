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

# 2. Same manual IPv4 on every physical Thunderbolt service (skip when the
#    address is already set, so a steady-state activation logs nothing).
while IFS= read -r tb_svc; do
  [ -n "$tb_svc" ] || continue
  if /usr/sbin/networksetup -getinfo "$tb_svc" 2>/dev/null | /usr/bin/grep -q "^IP address: $CLUSTER_LINK_IP$"; then
    continue
  fi
  if /usr/sbin/networksetup -setmanual "$tb_svc" "$CLUSTER_LINK_IP" 255.255.255.0 2>/dev/null; then
    echo "$prefix set $CLUSTER_LINK_IP on '$tb_svc'"
  else
    echo "$prefix WARN failed to set manual address on '$tb_svc'" >&2
  fi
done < <(printf '%s\n' "$order" \
  | /usr/bin/awk '/^\([0-9*]+\)/{sub(/^\([0-9*]+\) /,""); prev=$0; next} /Hardware Port: Thunderbolt [0-9]/{print prev}')

# 3. Sweep residual Thunderbolt members out of bridge0 (the disabled service
#    stops future enslavement; current members linger until removed).
while IFS= read -r tb_dev; do
  [ -n "$tb_dev" ] || continue
  if /sbin/ifconfig bridge0 2>/dev/null | /usr/bin/grep -q "member: $tb_dev "; then
    if /sbin/ifconfig bridge0 deletem "$tb_dev" 2>/dev/null; then
      echo "$prefix removed $tb_dev from bridge0"
    else
      echo "$prefix WARN failed to remove $tb_dev from bridge0" >&2
    fi
  fi
done < <(printf '%s\n' "$order" \
  | /usr/bin/awk -F'Device: ' '/Hardware Port: Thunderbolt [0-9]/{sub(/\)[[:space:]]*$/, "", $2); print $2}')
