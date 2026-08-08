#!/usr/bin/env bats
#
# The rebuild gate and the rank-live detection behind it, exercised against a
# stub launchctl. These assert BEHAVIOUR (exit status + the decision that was
# logged), not the presence of a string in a source file — a gate that stops
# refusing is the failure worth catching.

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

# Stubs get the shebang of the bash actually running the suite. `/usr/bin/env`
# is NOT available in the Nix build sandbox these tests run in, and a stub that
# fails to exec looks exactly like a launchctl that answered "no" — which
# silently turned every live-rank case into an undetermined one.
write_stub() {
  local path="$1"
  printf '#!%s\n' "$(command -v bash)" > "$path"
  cat >> "$path"
  chmod +x "$path"
}

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB_DIR"

  # Stub launchctl. LAUNCHCTL_MODE selects the machine state under test:
  #   running     — the rank agent is up
  #   stopped     — the domain exists, the rank agent is not running
  #   no-session  — there is no gui/<uid> domain at all
  write_stub "$STUB_DIR/launchctl" << 'STUB'
target="$2"
case "$LAUNCHCTL_MODE" in
  no-session) exit 113 ;;
  running)
    case "$target" in
      */dev.mlx-cluster.rank) echo "  state = running"; exit 0 ;;
      *) exit 0 ;;
    esac
    ;;
  stopped)
    case "$target" in
      */dev.mlx-cluster.rank) echo "  state = not running"; exit 0 ;;
      *) exit 0 ;;
    esac
    ;;
esac
exit 0
STUB

  export MLX_CLUSTER_LAUNCHCTL_BIN="$STUB_DIR/launchctl"
  export MLX_CLUSTER_GUI_UID=501

  # The gate invokes the detector as one executable path, exactly as the module
  # wires it, so the seam under test is the real one.
  write_stub "$STUB_DIR/rank-live" << STUB
exec bash -euo pipefail "$SCRIPTS/mlx-cluster-rank-live.sh"
STUB
  export MLX_CLUSTER_RANK_LIVE_BIN="$STUB_DIR/rank-live"
}

rank_live() {
  run bash -euo pipefail "$SCRIPTS/mlx-cluster-rank-live.sh"
}

gate() {
  run bash -euo pipefail "$SCRIPTS/cluster-rebuild-gate.sh"
}

# The two properties below live in how the activation script is ASSEMBLED, not
# in what the gate does when it runs, so no behavioural test above can see
# them. They are asserted against the source because this repo's `nix flake
# check` deliberately passes no darwinConfigurations (checks run on a Linux
# runner, source-only), so a generated-text assertion would never execute —
# and a check that cannot run is worse than none.

@test "the gate is ordered ahead of every other preActivation chunk" {
  # mkBefore (500) only orders against the default block; several modules here
  # already use mkBefore, and their relative order is merge order. Behind one
  # of them, the gate would refuse only after that chunk changed the machine.
  run grep -F "lib.mkOrder 50 activationSnippet" \
    "$BATS_TEST_DIRNAME/../../modules/darwin/cluster-rebuild-gate.nix"
  [ "$status" -eq 0 ]
}

@test "the activation snippet aborts explicitly rather than trusting set -e" {
  # Activation here runs `set +e` on purpose, so a gate that merely exited
  # non-zero would print a refusal and let the rebuild proceed.
  run grep -qE '^@gate@ \|\| exit 1$' \
    "$BATS_TEST_DIRNAME/../../modules/darwin/scripts/cluster-rebuild-gate-activation.sh"
  [ "$status" -eq 0 ]
}

@test "the stubs actually execute — a dead stub would fake every answer" {
  # Without this, a stub that cannot exec (wrong shebang for the environment)
  # returns non-zero for every query, which reads as "launchctl says no" and
  # turns the live-rank cases into passing undetermined ones.
  run env LAUNCHCTL_MODE=running "$STUB_DIR/launchctl" print gui/501/dev.mlx-cluster.rank
  [ "$status" -eq 0 ]
  [[ "$output" == *"state = running"* ]]
}

@test "rank-live reports LIVE (0) when the rank agent is running" {
  LAUNCHCTL_MODE=running rank_live
  [ "$status" -eq 0 ]
  [[ "$output" == *"LIVE"* ]]
}

@test "rank-live reports NOT LIVE (1) when the rank agent is stopped" {
  LAUNCHCTL_MODE=stopped rank_live
  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT LIVE"* ]]
}

@test "rank-live reports UNDETERMINED (2) when there is no GUI launchd domain" {
  LAUNCHCTL_MODE=no-session rank_live
  [ "$status" -eq 2 ]
  [[ "$output" == *"UNDETERMINED"* ]]
}

@test "rank-live reports UNDETERMINED (2) when no console user owns a session" {
  MLX_CLUSTER_GUI_UID=0 LAUNCHCTL_MODE=running rank_live
  [ "$status" -eq 2 ]
  [[ "$output" == *"UNDETERMINED"* ]]
}

@test "gate REFUSES activation while a rank is live" {
  LAUNCHCTL_MODE=running gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"REFUSING"* ]]
}

@test "gate names cluster teardown as the unlock and offers no override" {
  LAUNCHCTL_MODE=running gate
  [[ "$output" == *"Thunderbolt cable"* ]]
  [[ "$output" == *"no override"* ]]
}

@test "gate ALLOWS activation once the rank is stopped — the refusal is not a latch" {
  LAUNCHCTL_MODE=running gate
  [ "$status" -eq 1 ]
  LAUNCHCTL_MODE=stopped gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"ALLOWING"* ]]
}

@test "gate ALLOWS and logs the undetermined case rather than passing silently" {
  LAUNCHCTL_MODE=no-session gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"ALLOWING"* ]]
  [[ "$output" == *"UNDETERMINED"* ]]
}
