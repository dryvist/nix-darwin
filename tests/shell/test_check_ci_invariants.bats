#!/usr/bin/env bats
# Tests for scripts/workflows/check-ci-invariants.sh
#
# The point of these is the FAILURE cases. A guard that has only ever been seen
# to pass is not known to work — and this particular guard exists because a
# documented invariant was silently violated once already. Each test below
# breaks exactly one invariant and asserts the script goes red.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/workflows/check-ci-invariants.sh"
  GOOD="$REPO_ROOT/.github/workflows/_nix-build.yml"
  WORK="$BATS_TEST_TMPDIR/wf.yml"
  cp "$GOOD" "$WORK"
}

@test "passes on the real workflow" {
  run bash "$SCRIPT" "$GOOD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"invariants hold"* ]]
}

@test "fails when the workflow is missing" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nope.yml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"workflow not found"* ]]
}

@test "fails when the cache saves on main instead of develop" {
  sed -i.bak "s|refs/heads/develop' }}|refs/heads/main' }}|g" "$WORK"
  run bash "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unreadable to every PR"* ]]
}

@test "fails when the timeout is raised past the cap" {
  sed -i.bak 's|timeout-minutes: .*|timeout-minutes: 30|' "$WORK"
  run bash "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"timeout-minutes must stay"* ]]
}

@test "fails when the org-variable fallback is dropped" {
  sed -i.bak 's|timeout-minutes: .*|timeout-minutes: ${{ vars.GH_ACTION_TIMEOUT_NIX }}|' "$WORK"
  run bash "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"literal fallback is required"* ]]
}

@test "fails when cancel-in-progress stops exempting develop" {
  sed -i.bak 's|cancel-in-progress: .*|cancel-in-progress: true|' "$WORK"
  run bash "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"only branch that saves"* ]]
}

@test "fails when the cache is shrunk back below the org quota" {
  sed -i.bak 's|gc-max-store-size-macos: .*|gc-max-store-size-macos: 8G|' "$WORK"
  run bash "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gc-max-store-size-macos"* ]]
}

@test "fails when the prefix restore is removed" {
  sed -i.bak '/restore-prefixes-first-match/d' "$WORK"
  run bash "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cold-builds the closure"* ]]
}

@test "reports every broken invariant, not just the first" {
  sed -i.bak 's|timeout-minutes: .*|timeout-minutes: 30|' "$WORK"
  sed -i.bak '/restore-prefixes-first-match/d' "$WORK"
  run bash "$SCRIPT" "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"timeout-minutes must stay"* ]]
  [[ "$output" == *"cold-builds the closure"* ]]
}
