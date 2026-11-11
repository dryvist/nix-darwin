#!/usr/bin/env bats
#
# cluster-link-prep's interval guard, driven against stub ifconfig and networksetup. The case that
# matters most is the first: an active port that already carries the link address is skipped with
# zero mutating calls, because the full pass deletes and re-adds that address and a live cluster
# always has it on its active port. Also: the cases that must run the full pass, the one-line-per-
# change logging, and the activation path (guard switch unset) that always runs the full pass.

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"
LINK_IP=192.0.2.1
PEER_IP=192.0.2.2

# Stubs get the shebang of the bash running the suite; /usr/bin/env is absent in the Nix build sandbox.
write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

# One Thunderbolt device's `ifconfig <dev>` output: up|down, active|inactive, and whether it holds the address.
iface() {
  local dev="$1" admin="$2" carrier="$3" addr="$4" flags="flags=8822<BROADCAST,SMART,SIMPLEX,MULTICAST>"
  [ "$admin" = up ] && flags="flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST>"
  {
    echo "$dev: $flags mtu 1500"
    [ "$addr" = addr ] && echo "	inet $LINK_IP netmask 0xffffff00 broadcast 192.0.2.255"
    echo "	status: $carrier"
  } > "$STATE/$dev"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  export STATE="$BATS_TEST_TMPDIR/state"
  mkdir -p "$STUB_DIR" "$STATE"
  export MUTATIONS="$BATS_TEST_TMPDIR/mutations"
  : > "$MUTATIONS"
  : > "$STATE/bridge0"
  write_stub "$STUB_DIR/networksetup" << 'STUB'
case "$1" in
  -listnetworkserviceorder) echo "(1) Wi-Fi"; echo "(Hardware Port: Wi-Fi, Device: en0)" ;;
  -listallhardwareports)
    printf 'Hardware Port: Thunderbolt 1\nDevice: en1\n\nHardware Port: Thunderbolt 2\nDevice: en2\n\n' ;;
  *) echo "networksetup $*" >> "$MUTATIONS" ;;
esac
STUB
  write_stub "$STUB_DIR/ifconfig" << 'STUB'
if [ "$#" -eq 1 ]; then cat "$STATE/$1" 2>/dev/null; exit 0; fi
echo "ifconfig $*" >> "$MUTATIONS"
STUB
  export CLUSTER_LINK_IP="$LINK_IP" CLUSTER_PEER_LINK_IP="$PEER_IP"
  export CLUSTER_LINK_PREP_IFCONFIG="$STUB_DIR/ifconfig"
  export CLUSTER_LINK_PREP_NETWORKSETUP="$STUB_DIR/networksetup"
  export CLUSTER_LINK_PREP_STATE_FILE="$BATS_TEST_TMPDIR/guard-state"
}

run_guarded() {
  run env CLUSTER_LINK_PREP_GUARD=1 bash -euo pipefail "$SCRIPTS/cluster-link-prep.sh"
}

@test "1: an active port with the address is skipped with zero mutating calls" {
  iface en1 up active addr
  iface en2 up inactive no
  run_guarded
  [ "$status" -eq 0 ]
  [[ "$output" == *"[cluster-link-prep] guard=link-prep decision=skip reason=address-present dev=en1"* ]]
  [ "$(wc -l < "$MUTATIONS")" -eq 0 ]
}

@test "1b: the address-present skip wins over a down or bridged sibling port" {
  iface en1 up active addr
  iface en2 down inactive no
  echo "	member: en2 flags=3<LEARNING,DISCOVER>" > "$STATE/bridge0"
  run_guarded
  [[ "$output" == *"decision=skip reason=address-present dev=en1"* ]]
  [ "$(wc -l < "$MUTATIONS")" -eq 0 ]
}

@test "2: an active port without the address runs the full pass and assigns it there" {
  iface en1 up inactive no
  iface en2 up active no
  run_guarded
  [ "$status" -eq 0 ]
  [[ "$output" == *"decision=run reason=carrier-without-address dev=en2"* ]]
  grep -qx "ifconfig en2 inet $LINK_IP netmask 255.255.255.0 alias" "$MUTATIONS"
  [ "$(grep -c "ifconfig en1 inet $LINK_IP" "$MUTATIONS")" = 0 ]
}

@test "3: no active port, all up, none bridged is skipped with zero mutating calls" {
  iface en1 up inactive no
  iface en2 up inactive no
  run_guarded
  [ "$status" -eq 0 ]
  [[ "$output" == *"decision=skip reason=no-carrier dev=-"* ]]
  [ "$(wc -l < "$MUTATIONS")" -eq 0 ]
}

@test "4a: a port that is down runs the full pass" {
  iface en1 down inactive no
  iface en2 up inactive no
  run_guarded
  [[ "$output" == *"decision=run reason=port-down dev=en1"* ]]
  grep -qx "ifconfig en1 up" "$MUTATIONS"
}

@test "4b: a port in bridge0 runs the full pass" {
  iface en1 up inactive no
  iface en2 up inactive no
  echo "	member: en2 flags=3<LEARNING,DISCOVER>" > "$STATE/bridge0"
  run_guarded
  [[ "$output" == *"decision=run reason=bridge-member dev=en2"* ]]
  grep -qx "ifconfig bridge0 deletem en2" "$MUTATIONS"
}

@test "5: the same decision twice in a row logs one line, a changed one logs again" {
  iface en1 up inactive no
  iface en2 up inactive no
  run_guarded
  run_guarded
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  iface en2 up active addr
  run_guarded
  [[ "$output" == *"decision=skip reason=address-present dev=en2"* ]]
}

@test "6: with the guard switch unset the full pass runs even when the address is present" {
  iface en1 up active addr
  iface en2 up inactive no
  run bash -euo pipefail "$SCRIPTS/cluster-link-prep.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"guard=link-prep"* ]]
  grep -qx "ifconfig en1 inet $LINK_IP delete" "$MUTATIONS"
  grep -qx "ifconfig en1 inet $LINK_IP netmask 255.255.255.0 alias" "$MUTATIONS"
}
