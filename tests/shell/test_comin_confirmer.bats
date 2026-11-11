#!/usr/bin/env bats
#
# comin-confirmer, driven against a stub comin and a stub cluster rebuild gate. The case that matters
# most is the refusal: while the gate refuses (the host is clustered), nothing is confirmed and the
# refusal is logged. Also: an allowed gate confirms, nothing waiting means no gate call and no log,
# and an unreadable comin state confirms nothing.

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

# Stubs get the shebang of the bash running the suite; /usr/bin/env is absent in the Nix build sandbox.
write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB_DIR"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  : > "$CALLS"
  write_stub "$STUB_DIR/comin" << 'STUB'
echo "comin $*" >> "$CALLS"
if [ "$1" = status ]; then
  [ "${COMIN_STATUS_FAIL:-}" = 1 ] && { echo "connection refused" >&2; exit 1; }
  printf '%s' "$COMIN_STATUS"
fi
STUB
  write_stub "$STUB_DIR/cluster-rebuild-gate" << 'STUB'
echo "gate" >> "$CALLS"
if [ "$GATE" = allow ]; then
  echo "cluster-rebuild-gate: ALLOWING — no cluster rank is live on this host; link-state down."
  exit 0
fi
echo "cluster-rebuild-gate: REFUSING to activate — link-state is up and peer-state reports armed." >&2
echo "cluster-rebuild-gate: There is deliberately no override." >&2
exit 1
STUB
  export PATH="$STUB_DIR:$PATH"
  export CLUSTER_REBUILD_GATE_BIN="$STUB_DIR/cluster-rebuild-gate"
  export COMIN_STATUS='{"deploy_confirmer":{"submitted":"gen-1"},"deployer":{"is_deploying":false}}'
}

run_confirmer() {
  run bash -euo pipefail "$SCRIPTS/comin-confirmer.sh"
}

@test "a clustered host confirms nothing and logs the gate's refusal" {
  GATE=refuse run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"REFUSING generation gen-1 until the next check: cluster-rebuild-gate: REFUSING to activate — link-state is up and peer-state reports armed."* ]]
  grep -qx gate "$CALLS"
  [ "$(grep -c '^comin confirmation' "$CALLS")" = 0 ]
}

@test "an allowed gate confirms the waiting generation" {
  GATE=allow run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONFIRMING generation gen-1: cluster-rebuild-gate: ALLOWING"* ]]
  grep -qx 'comin confirmation accept' "$CALLS"
}

@test "nothing waiting: no gate call, no confirmation, no log line" {
  GATE=allow COMIN_STATUS='{"deploy_confirmer":{"submitted":""}}' run_confirmer
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(grep -c '^gate' "$CALLS")" = 0 ]
  [ "$(grep -c '^comin confirmation' "$CALLS")" = 0 ]
}

@test "an unreadable comin state confirms nothing" {
  GATE=allow COMIN_STATUS_FAIL=1 run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"comin state unreadable; confirming nothing: connection refused"* ]]
  [ "$(grep -c '^gate' "$CALLS")" = 0 ]
  [ "$(grep -c '^comin confirmation' "$CALLS")" = 0 ]
}

@test "a non-JSON comin state confirms nothing" {
  GATE=allow COMIN_STATUS='not json' run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"comin state is not JSON; confirming nothing."* ]]
  [ "$(grep -c '^comin confirmation' "$CALLS")" = 0 ]
}

@test "with the real rebuild gate, link up and armed refuses and confirms nothing" {
  home="$BATS_TEST_TMPDIR/home"
  state="$home/Library/Application Support/mlx-cluster"
  mkdir -p "$state"
  echo up > "$state/link-state"
  echo '{"armed": true}' > "$state/peer-state.json"
  write_stub "$STUB_DIR/rank-live" << 'STUB'
exit 1
STUB
  write_stub "$STUB_DIR/real-gate" << STUB
export MLX_CLUSTER_RANK_LIVE_BIN="$STUB_DIR/rank-live" CLUSTER_USER_HOME="$home"
exec bash -euo pipefail "$SCRIPTS/cluster-rebuild-gate.sh"
STUB
  CLUSTER_REBUILD_GATE_BIN="$STUB_DIR/real-gate" run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"REFUSING generation gen-1 until the next check: cluster-rebuild-gate: REFUSING to activate — link-state is up and peer-state reports armed."* ]]
  [ "$(grep -c '^comin confirmation' "$CALLS")" = 0 ]

  echo down > "$state/link-state"
  : > "$CALLS"
  CLUSTER_REBUILD_GATE_BIN="$STUB_DIR/real-gate" run_confirmer
  [[ "$output" == *"CONFIRMING generation gen-1: cluster-rebuild-gate: ALLOWING — no cluster rank is live on this host; link-state down."* ]]
  grep -qx 'comin confirmation accept' "$CALLS"
}
