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

# 1.5 Bring every Thunderbolt device UP before any carrier is read. Removing a
#     port from bridge0 leaves the device administratively down (flags=8822,
#     no UP), and a down device reports `status: inactive` even with a live
#     cable in it. Step 2 assigns the address ONLY to a carrier-active device,
#     so without this the sweep above silently guarantees step 2 matches
#     nothing and assigns no address at all — on both hosts, permanently, and
#     NOT healed by a later boot or rebuild, because those rerun the same sweep.
#
#     Observed 2026-07-25 on the first TB5 cluster window: a cable connected
#     the whole time produced no link on either host, `ifconfig -a` showed no
#     link address anywhere, and a `darwin-rebuild switch` earlier that evening
#     had not fixed it. `ifconfig <dev> up` restored carrier immediately and
#     the prep then assigned both ends' addresses with no other change.
#
#     Bringing up ALL Thunderbolt devices keeps step 2's single-carrier rule
#     intact: an uncabled port comes up without carrier, stays `inactive`, and
#     is skipped there exactly as before.
while IFS= read -r tb_dev; do
  [ -n "$tb_dev" ] || continue
  /sbin/ifconfig "$tb_dev" up 2>/dev/null \
    || echo "$prefix WARN failed to bring $tb_dev up" >&2
done < <(/usr/sbin/networksetup -listallhardwareports \
  | /usr/bin/awk '/^Hardware Port: Thunderbolt [0-9]/{getline; sub(/^Device: /, ""); print}')

# Thunderbolt negotiation is not instant after `up`; reading carrier in the
# same breath can still see `inactive` on a cabled port and skip it. One short
# settle rather than a per-device poll — the prep reruns at every boot and
# rebuild, so a rare miss self-heals instead of needing a retry loop here.
/bin/sleep 3

# 2. Same link IPv4 directly on every physical Thunderbolt DEVICE via
#    ifconfig — deliberately NOT SystemConfiguration services: on macOS 26,
#    `networksetup -createnetworkservice` fails as root with "Unable to
#    access the System Configuration database" even for un-enslaved ports
#    (verified 2026-07-18), so per-port services cannot be created at all on
#    hosts that never had them. Persistence comes from this prep rerunning at
#    every boot + rebuild (root postActivation), which is the module's
#    existing contract. Only one port is ever cabled; un-cabled ports have no
#    carrier, so the shared address is inert on them.
#    ONLY the carrier-active device gets the address: with the same subnet
#    aliased on several up interfaces the kernel binds the /24 route to the
#    FIRST one, which silently blackholes traffic when the cable sits on a
#    different port (verified 2026-07-18: worker route pinned to en1 while
#    the cable was on en2). Stripping the alias elsewhere keeps the route on
#    the cabled port; a cable move heals on the next boot/rebuild (this prep
#    reruns then).
assigned=false
while IFS= read -r tb_dev; do
  [ -n "$tb_dev" ] || continue
  dev_state="$(/sbin/ifconfig "$tb_dev" 2>/dev/null)"
  has_ip=false
  case "$dev_state" in *"inet $CLUSTER_LINK_IP "*) has_ip=true ;; esac
  is_active=false
  case "$dev_state" in *"status: active"*) is_active=true ;; esac
  if $is_active; then
    assigned=true
    # Re-plumb even when the address is already present: deleting the alias
    # from a SIBLING port can drop the shared connected route out from under
    # this one (observed 2026-07-18 — traffic then fell through to the
    # default route on an unrelated NIC). Delete+add restores the route.
    # Guarded so a transient delete failure neither aborts the script under
    # an inherited `set -e` nor skips the alias re-add below.
    if $has_ip; then
      /sbin/ifconfig "$tb_dev" inet "$CLUSTER_LINK_IP" delete \
        || echo "$prefix WARN failed to delete $CLUSTER_LINK_IP from $tb_dev before re-add" >&2
    fi
    if /sbin/ifconfig "$tb_dev" inet "$CLUSTER_LINK_IP" netmask 255.255.255.0 alias; then
      echo "$prefix set $CLUSTER_LINK_IP on $tb_dev (carrier active)"
    else
      echo "$prefix WARN failed to set $CLUSTER_LINK_IP on $tb_dev" >&2
    fi
  elif ! $is_active && $has_ip; then
    if /sbin/ifconfig "$tb_dev" inet "$CLUSTER_LINK_IP" delete; then
      echo "$prefix removed $CLUSTER_LINK_IP from $tb_dev (no carrier)"
    else
      echo "$prefix WARN failed to remove $CLUSTER_LINK_IP from $tb_dev" >&2
    fi
  fi
done < <(/usr/sbin/networksetup -listallhardwareports \
  | /usr/bin/awk '/^Hardware Port: Thunderbolt [0-9]/{getline; sub(/^Device: /, ""); print}')

# Say so when nothing was addressed. This prep is invoked from postActivation
# with `|| echo "…non-fatal failure"` so it can never fail a rebuild — which
# means a run that assigns NO address still reports a clean activation, and the
# cluster silently cannot form (the watcher's only link test is a ping to the
# peer's address, so with no local address it never sees "up"). That is exactly
# how the 2026-07-25 failure stayed invisible across a rebuild. Still exit 0 —
# an uncabled host is the normal state and must not be an error — but leave a
# greppable line so the cause is one search away instead of a live debug.
if ! $assigned; then
  echo "$prefix WARN no Thunderbolt port had carrier; $CLUSTER_LINK_IP was NOT assigned." >&2
  echo "$prefix WARN if a cable IS connected, check the ports are up: ifconfig <tb-dev> up" >&2
fi
