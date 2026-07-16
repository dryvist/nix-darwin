# Cluster-link converge — one tick per launchd interval (root).
#
# Finds the active RDMA-capable Thunderbolt interface (the cabled port),
# keeps it out of bridge0, and converges this host's role-derived link
# address onto it. Moving the cable to another port converges within one
# tick — no config change.
#
# Consumed environment (set declaratively by the LaunchDaemon):
#   CLUSTER_LINK_IP          this host's link address (role-derived synthetic)
#   CLUSTER_WIRED_LIMIT_MB   optional: iogpu.wired_limit_mb to hold while the
#                            link is active (shard-sized night ceiling)
#   DAY_WIRED_LIMIT_MB       restore value for link-down (0 = OS default);
#                            only read when CLUSTER_WIRED_LIMIT_MB is set

# Guard rails: RDMA tooling may be absent (non-RDMA host) and the link IP
# comes from the plist — bail cleanly rather than erroring every 30s tick.
[ -x /usr/bin/ibv_devices ] || exit 0
: "${CLUSTER_LINK_IP:?CLUSTER_LINK_IP must be set}"

# Idempotent wired-ceiling write: no-op when unset (profile disabled) or when
# the sysctl already holds the target, so a steady state logs nothing.
set_wired_limit() {
  local target="$1" current
  if [ -z "$target" ]; then
    return 0
  fi
  current="$(/usr/sbin/sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo '')"
  if [ "$current" = "$target" ]; then
    return 0
  fi
  if /usr/sbin/sysctl -w "iogpu.wired_limit_mb=$target" > /dev/null 2>&1 &&
    [ "$(/usr/sbin/sysctl -n iogpu.wired_limit_mb 2>/dev/null)" = "$target" ]; then
    echo "cluster-link: iogpu.wired_limit_mb=$target"
  else
    echo "cluster-link: WARN failed to set iogpu.wired_limit_mb=$target" >&2
  fi
}

iface=""
for dev in $(/usr/bin/ibv_devices 2>/dev/null | /usr/bin/awk 'NR>2 {print $1}'); do
  cand="${dev#rdma_}"
  if /sbin/ifconfig "$cand" 2>/dev/null | /usr/bin/grep -q "status: active"; then
    # ponytail: first active RDMA-capable port wins; disambiguation only
    # matters if an RDMA-capable TB device besides the peer Mac is attached.
    iface="$cand"
    break
  fi
done

if [ -z "$iface" ]; then
  # No cable: nothing to converge, but make sure the day wired ceiling is
  # back (the set-iogpu-wired-limit daemon only runs at boot/rebuild, so the
  # link-down restore has to happen here).
  set_wired_limit "${CLUSTER_WIRED_LIMIT_MB:+${DAY_WIRED_LIMIT_MB:-0}}"
  exit 0
fi

# Link active: hold the shard-sized night ceiling BEFORE the rank's model
# load can wire day-sized memory. The user-side link watcher ticks on its own
# 30s interval, so the ceiling can land up to one tick after the rank starts;
# the 198GB load takes minutes, which absorbs that skew.
set_wired_limit "${CLUSTER_WIRED_LIMIT_MB:-}"

if /sbin/ifconfig bridge0 2>/dev/null | /usr/bin/grep -q "member: $iface "; then
  /sbin/ifconfig bridge0 deletem "$iface" && echo "cluster-link: removed $iface from bridge0"
fi

if ! /sbin/ifconfig "$iface" 2>/dev/null | /usr/bin/grep -q "inet $CLUSTER_LINK_IP "; then
  # The cable moved (or first assignment): clear the address from any other
  # interface, then alias it onto the live port.
  for other in $(/sbin/ifconfig -l); do
    [ "$other" = "$iface" ] && continue
    if /sbin/ifconfig "$other" 2>/dev/null | /usr/bin/grep -q "inet $CLUSTER_LINK_IP "; then
      /sbin/ifconfig "$other" inet "$CLUSTER_LINK_IP" -alias
      echo "cluster-link: cleared $CLUSTER_LINK_IP from $other"
    fi
  done
  /sbin/ifconfig "$iface" inet "$CLUSTER_LINK_IP" netmask 255.255.255.0 alias
  echo "cluster-link: assigned $CLUSTER_LINK_IP to $iface"
fi
