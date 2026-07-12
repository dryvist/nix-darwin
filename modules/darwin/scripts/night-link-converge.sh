# Night-link converge — one tick per launchd interval (root).
#
# Finds the active RDMA-capable Thunderbolt interface (the cabled port),
# keeps it out of bridge0, and converges this host's role-derived link
# address onto it. Moving the cable to another port converges within one
# tick — no config change.
#
# Consumed environment (set declaratively by the LaunchDaemon):
#   NIGHT_LINK_IP   this host's link address (role-derived synthetic)

# Guard rails: RDMA tooling may be absent (non-RDMA host) and the link IP
# comes from the plist — bail cleanly rather than erroring every 30s tick.
[ -x /usr/bin/ibv_devices ] || exit 0
: "${NIGHT_LINK_IP:?NIGHT_LINK_IP must be set}"

iface=""
for dev in $(/usr/bin/ibv_devices 2>/dev/null | awk 'NR>2 {print $1}'); do
  cand="${dev#rdma_}"
  if /sbin/ifconfig "$cand" 2>/dev/null | grep -q "status: active"; then
    # ponytail: first active RDMA-capable port wins; disambiguation only
    # matters if an RDMA-capable TB device besides the peer Mac is attached.
    iface="$cand"
    break
  fi
done

if [ -z "$iface" ]; then
  exit 0 # no cable; nothing to converge
fi

if /sbin/ifconfig bridge0 2>/dev/null | grep -q "member: $iface "; then
  /sbin/ifconfig bridge0 deletem "$iface" && echo "night-link: removed $iface from bridge0"
fi

if ! /sbin/ifconfig "$iface" 2>/dev/null | grep -q "inet $NIGHT_LINK_IP "; then
  # The cable moved (or first assignment): clear the address from any other
  # interface, then alias it onto the live port.
  for other in $(/sbin/ifconfig -l); do
    [ "$other" = "$iface" ] && continue
    if /sbin/ifconfig "$other" 2>/dev/null | grep -q "inet $NIGHT_LINK_IP "; then
      /sbin/ifconfig "$other" inet "$NIGHT_LINK_IP" -alias
      echo "night-link: cleared $NIGHT_LINK_IP from $other"
    fi
  done
  /sbin/ifconfig "$iface" inet "$NIGHT_LINK_IP" netmask 255.255.255.0 alias
  echo "night-link: assigned $NIGHT_LINK_IP to $iface"
fi
