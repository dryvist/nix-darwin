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
  GOOD_CALLER="$REPO_ROOT/.github/workflows/ci-nix.yml"
  WORK="$BATS_TEST_TMPDIR/wf.yml"
  CALLER="$BATS_TEST_TMPDIR/caller.yml"
  cp "$GOOD" "$WORK"
  cp "$GOOD_CALLER" "$CALLER"
  # `cp` preserves mode, and under `nix flake check` the sources are read-only
  # store paths (444). `sed -i` still works there because it only needs a
  # writable directory, but a `>` redirect needs a writable file — so tests that
  # rewrite a fixture wholesale fail in the sandbox while passing locally.
  chmod u+w "$WORK" "$CALLER"
}

@test "passes on the real workflow" {
  run bash "$SCRIPT" "$GOOD" "$GOOD_CALLER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"invariants hold"* ]]
}

@test "fails when the workflow is missing" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nope.yml" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"workflow not found"* ]]
}

@test "fails when the caller workflow is missing" {
  run bash "$SCRIPT" "$GOOD" "$BATS_TEST_TMPDIR/nope.yml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"caller workflow not found"* ]]
}

# A called workflow can never exceed its caller's grant. Omitting this on the
# caller kills the run at graph validation -- startup_failure, no job, no logs,
# and no check-runs at all, so the PR shows a CLEAN merge state with nothing red.
@test "fails when the caller does not grant actions: write" {
  sed -i.bak '/actions: write/d' "$CALLER"
  run bash "$SCRIPT" "$GOOD" "$CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"without 'actions: write'"* ]]
}

# The false-pass that a whole-file grep allows, and the one that actually
# happened: ci-gate.yml DID contain "actions: write" -- on its shared-gate job,
# not on the nix-build job that calls _nix-build.yml. Permissions are per-job,
# so the run still died. The guard must read the calling job, not the file.
@test "fails when actions: write is on a different job than the caller" {
  cat >"$CALLER" <<'YAML'
name: fake
permissions:
  contents: read
jobs:
  other-job:
    permissions:
      contents: read
      actions: write
    uses: ./.github/workflows/_something-else.yml
  nix-build:
    uses: ./.github/workflows/_nix-build.yml
YAML
  run bash "$SCRIPT" "$GOOD" "$CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"permissions are per-job"* ]]
}

@test "accepts a workflow-level actions: write grant" {
  cat >"$CALLER" <<'YAML'
name: fake
permissions:
  contents: read
  actions: write
jobs:
  build:
    uses: ./.github/workflows/_nix-build.yml
YAML
  run bash "$SCRIPT" "$GOOD" "$CALLER"
  [ "$status" -eq 0 ]
}

# Prose naming the workflow is not a call site. ci-nix.yml discusses
# _nix-build.yml in its header comments, which a substring match misread as a
# job that calls it.
@test "does not treat a comment mentioning _nix-build.yml as a call site" {
  cat >"$CALLER" <<'YAML'
name: fake
# This workflow pairs with _nix-build.yml and its save: condition.
permissions:
  contents: read
jobs:
  unrelated:
    runs-on: ubuntu-latest
    steps:
      - run: 'true'
YAML
  run bash "$SCRIPT" "$GOOD" "$CALLER"
  [ "$status" -eq 0 ]
}

@test "fails when ci-nix stops exempting develop from cancellation" {
  sed -i.bak "s|github.ref != 'refs/heads/develop'|true|" "$CALLER"
  run bash "$SCRIPT" "$GOOD" "$CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"only branch that saves"* ]]
}

@test "fails when the cache saves on main instead of develop" {
  sed -i.bak "s|refs/heads/develop' }}|refs/heads/main' }}|g" "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unreadable to every PR"* ]]
}

@test "fails when the timeout is raised past the cap" {
  sed -i.bak 's|timeout-minutes: .*|timeout-minutes: 30|' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"timeout-minutes must stay"* ]]
}

@test "fails when the org-variable fallback is dropped" {
  sed -i.bak 's|timeout-minutes: .*|timeout-minutes: ${{ fromJSON(vars.GH_ACTION_TIMEOUT_NIX) }}|' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"timeout-minutes must stay"* ]]
}

# Regression guard: dropping fromJSON is silently catastrophic. vars.* is typed
# as a string and timeout-minutes requires a number, so the workflow fails graph
# validation and the job never runs — surfacing as a failed required check with
# no job and no logs, which is easily misread as an infrastructure flake.
@test "fails when fromJSON is dropped from the timeout expression" {
  sed -i.bak "s|timeout-minutes: .*|timeout-minutes: \${{ vars.GH_ACTION_TIMEOUT_NIX \|\| 15 }}|" "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fromJSON is required"* ]]
}

@test "fails when cancel-in-progress stops exempting develop" {
  sed -i.bak 's|cancel-in-progress: .*|cancel-in-progress: true|' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"only branch that saves"* ]]
}

@test "fails when the cache is shrunk below the non-substitutable tail" {
  sed -i.bak 's|gc-max-store-size-macos: .*|gc-max-store-size-macos: 2G|' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gc-max-store-size-macos"* ]]
}

# Regression guard for the opposite mistake: raising this back up looks like a
# safe, generous choice, but measured extraction time scales with cache size —
# 12G cost 8m28s to unpack for a 55s build. Bigger is not better past the size
# of the tail the cache needs to cover.
@test "fails when the cache is raised back past the tail it needs to cover" {
  sed -i.bak 's|gc-max-store-size-macos: .*|gc-max-store-size-macos: 12G|' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gc-max-store-size-macos"* ]]
}

@test "fails when the prefix restore is removed" {
  sed -i.bak '/restore-prefixes-first-match/d' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cold-builds the closure"* ]]
}

# Regression guards for the quota thrash. Purging looks like an optimisation
# worth "simplifying away" — it is not. Without it one cache accumulates per
# flake.lock hash until the repo exceeds its 15G quota and GitHub evicts entries
# of its own choosing, cold-starting PRs for entirely unrelated reasons.
@test "fails when purging is disabled" {
  sed -i.bak '/^          purge: /d' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"exceeds its quota"* ]]
}

@test "fails when purge is not gated to the saving branch" {
  sed -i.bak 's|^          purge: .*|          purge: true|' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"purge: must stay pinned"* ]]
}

@test "fails when the primary-key exemption is dropped" {
  sed -i.bak '/purge-primary-key/d' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"purge the very cache it just saved"* ]]
}

@test "fails when purge-created stops selecting every superseded cache" {
  sed -i.bak 's|purge-created: 0|purge-created: 604800|' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"re-creates the quota thrash"* ]]
}

# Shipped once without this permission. The purge selected the right caches,
# then failed to delete them with "Resource not accessible by integration" — and
# the step still exited green, so the only symptom was `gh cache list` refusing
# to shrink. A silent failure is exactly what a guard is for.
@test "fails when actions: write is dropped" {
  sed -i.bak '/actions: write/d' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Resource not accessible by integration"* ]]
}

@test "reports every broken invariant, not just the first" {
  sed -i.bak 's|timeout-minutes: .*|timeout-minutes: 30|' "$WORK"
  sed -i.bak '/restore-prefixes-first-match/d' "$WORK"
  run bash "$SCRIPT" "$WORK" "$GOOD_CALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"timeout-minutes must stay"* ]]
  [[ "$output" == *"cold-builds the closure"* ]]
}
