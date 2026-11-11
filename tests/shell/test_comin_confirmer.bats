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
  export COMIN_HOLD_FILE="$BATS_TEST_TMPDIR/comin-hold"
  export COMIN_WAITING_FILE="$BATS_TEST_TMPDIR/comin-confirmer.waiting"
}

# UTC timestamp offset from now by a GNU date relative expression ("+2 hours").
at() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }

write_hold() {
  printf '%s\n' "$@" > "$COMIN_HOLD_FILE"
}

no_confirmation() { [ "$(grep -c '^comin confirmation' "$CALLS")" = 0 ]; }
no_gate() { [ "$(grep -c '^gate' "$CALLS")" = 0 ]; }

run_hold() {
  run bash -euo pipefail "$SCRIPTS/comin-hold.sh" "$@"
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

@test "an unreachable comin control server logs alert=comin-control-unreachable on one capped line" {
  write_stub "$STUB_DIR/comin" << 'STUB'
echo "comin $*" >> "$CALLS"
printf 'dial unix /run/comin-grpc.sock: connect: connection refused %0300d\nsecond line\n' 0 >&2
exit 1
STUB
  GATE=allow run_confirmer
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == *"comin-confirmer: alert=comin-control-unreachable comin state unreadable; confirming nothing: dial unix /run/comin-grpc.sock: connect: connection refused"* ]]
  [ "${#output}" -lt 320 ]
  no_gate
  no_confirmation
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

@test "a valid hold confirms nothing, skips the gate and logs who, why, until and the generation" {
  until_ts="$(at '+2 hours')"
  write_hold "by=agent-team" "why=mid-task on this host" "set=$(at '-10 minutes')" "until=$until_ts"
  GATE=allow run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"HOLD by=agent-team why=mid-task on this host until=$until_ts; confirming nothing, cluster gate not consulted; waiting generation: gen-1"* ]]
  no_gate
  no_confirmation
}

@test "a valid hold with nothing waiting logs the hold and confirms nothing" {
  write_hold "by=agent-team" "why=mid-task" "set=$(at '-1 minutes')" "until=$(at '+1 hours')"
  GATE=allow COMIN_STATUS='{"deploy_confirmer":{"submitted":""}}' run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"HOLD by=agent-team why=mid-task"*"waiting generation: none"* ]]
  no_gate
  no_confirmation
}

@test "hold values are logged on one line with control characters stripped and length capped" {
  long="$(printf 'x%.0s' $(seq 1 400))"
  printf 'by=agent\033[31mteam\nwhy=%s\nset=%s\nuntil=%s\n' "$long" "$(at '-1 minutes')" "$(at '+1 hours')" > "$COMIN_HOLD_FILE"
  GATE=allow run_confirmer
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == *"by=agent[31mteam why=$(printf 'x%.0s' $(seq 1 200)) until="* ]]
  [[ "$output" != *$'\033'* ]]
  no_confirmation
}

@test "an expired hold confirms as today and logs alert=hold-expired" {
  write_hold "by=agent-team" "why=done" "set=$(at '-3 hours')" "until=$(at '-1 hours')"
  GATE=allow run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"comin-confirmer: alert=hold-expired"* ]]
  [[ "$output" == *"CONFIRMING generation gen-1: cluster-rebuild-gate: ALLOWING"* ]]
  grep -qx 'comin confirmation accept' "$CALLS"
}

@test "malformed holds are treated as absent and logged" {
  now_set="$(at '-1 minutes')"
  for hold in \
    "missing-why|by=a|set=$now_set|until=$(at '+1 hours')" \
    "bad-time|by=a|why=b|set=$now_set|until=tomorrow" \
    "over-12h-from-set|by=a|why=b|set=$(at '-1 hours')|until=$(at '+11 hours 30 minutes')" \
    "over-12h-ahead|by=a|why=b|set=$(at '+1 hours')|until=$(at '+12 hours 30 minutes')" \
    "until-before-set|by=a|why=b|set=$now_set|until=$(at '-2 minutes')" \
    "duplicate-key|by=a|by=c|why=b|set=$now_set|until=$(at '+1 hours')" \
    "empty|"; do
    name="${hold%%|*}"
    IFS='|' read -r -a fields <<< "${hold#*|}"
    : > "$COMIN_HOLD_FILE"
    for field in "${fields[@]}"; do [ -n "$field" ] && printf '%s\n' "$field" >> "$COMIN_HOLD_FILE"; done
    : > "$CALLS"
    GATE=allow run_confirmer
    [ "$status" -eq 0 ] || { echo "$name: exit $status"; false; }
    [[ "$output" == *"hold file $COMIN_HOLD_FILE ignored ("*"); treated as absent"* ]] || { echo "$name: $output"; false; }
    [[ "$output" != *"alert=hold-expired"* ]] || { echo "$name: alerted"; false; }
    grep -qx 'comin confirmation accept' "$CALLS" || { echo "$name: not confirmed"; false; }
  done
}

@test "an unreadable hold is treated as absent and logged" {
  mkdir "$COMIN_HOLD_FILE"
  GATE=allow run_confirmer
  [ "$status" -eq 0 ]
  [[ "$output" == *"hold file $COMIN_HOLD_FILE ignored (unreadable); treated as absent"* ]]
  grep -qx 'comin confirmation accept' "$CALLS"
}

@test "alert=generation-waiting-24h appears only past 24 hours and clears when the generation changes" {
  GATE=refuse run_confirmer
  [[ "$output" != *"alert=generation-waiting-24h"* ]]
  [ "$(cut -d' ' -f1 "$COMIN_WAITING_FILE")" = gen-1 ]

  printf 'gen-1 %s\n' "$(date -u -d '-23 hours' +%s)" > "$COMIN_WAITING_FILE"
  GATE=refuse run_confirmer
  [[ "$output" != *"alert=generation-waiting-24h"* ]]

  printf 'gen-1 %s\n' "$(date -u -d '-25 hours' +%s)" > "$COMIN_WAITING_FILE"
  GATE=refuse run_confirmer
  [[ "$output" == *"comin-confirmer: alert=generation-waiting-24h generation=gen-1 since="* ]]
  no_confirmation

  GATE=refuse COMIN_STATUS='{"deploy_confirmer":{"submitted":"gen-2"}}' run_confirmer
  [[ "$output" != *"alert=generation-waiting-24h"* ]]
  [ "$(cut -d' ' -f1 "$COMIN_WAITING_FILE")" = gen-2 ]

  GATE=refuse COMIN_STATUS='{"deploy_confirmer":{"submitted":""}}' run_confirmer
  [ -z "$output" ]
  [ ! -e "$COMIN_WAITING_FILE" ]
}

@test "comin-hold set writes a hold the confirmer honours; show prints it; clear removes it" {
  run_hold set --by agent-team --why "mid-task" --for 2h
  [ "$status" -eq 0 ]
  grep -qx 'by=agent-team' "$COMIN_HOLD_FILE"
  grep -qx 'why=mid-task' "$COMIN_HOLD_FILE"
  [ "$(stat -c %a "$COMIN_HOLD_FILE" 2> /dev/null || stat -f %Lp "$COMIN_HOLD_FILE")" = 644 ]
  run_hold show
  [ "$status" -eq 0 ]
  [[ "$output" == *"by=agent-team"* ]]
  GATE=allow run_confirmer
  [[ "$output" == *"HOLD by=agent-team why=mid-task"* ]]
  no_confirmation
  run_hold clear
  [ "$status" -eq 0 ]
  [ ! -e "$COMIN_HOLD_FILE" ]
  run_hold show
  [[ "$output" == *"no hold"* ]]
}

@test "comin-hold set rejects more than 12 hours, a missing --why and an unknown duration" {
  run_hold set --by a --why b --for 13h
  [ "$status" -ne 0 ]
  run_hold set --by a --why b --for 721m
  [ "$status" -ne 0 ]
  run_hold set --by a --for 1h
  [ "$status" -ne 0 ]
  run_hold set --by a --why b --for 1d
  [ "$status" -ne 0 ]
  [ ! -e "$COMIN_HOLD_FILE" ]
  run_hold set --by a --why b --for 12h
  [ "$status" -eq 0 ]
}
