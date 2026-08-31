#!/usr/bin/env bash
# check-ci-invariants.sh — Assert the macOS build workflow's cost-control invariants.
#
# Each invariant below was set deliberately after a measured regression, and each
# is a plausible "cleanup" for someone — human or agent — debugging a slow or red
# build. A comment did not hold the line last time: the cache-scoping bug
# recurred despite being documented in the very file it broke. So they are
# asserted here, where violating one turns a required check red.
#
# If you are reading this because the check failed: the fix is almost never to
# relax the assertion. Find the closure or dependency regression instead.
#
# Usage: check-ci-invariants.sh [path/to/_nix-build.yml] [caller.yml ...]
#
# Every argument after the first is a CALLER. Some invariants can only hold
# there: a called workflow can never exceed its caller's permission grant, so a
# scope the callee needs must also be granted by every workflow that calls it.

set -euo pipefail

wf="${1:-.github/workflows/_nix-build.yml}"
shift || true
if [ "$#" -gt 0 ]; then
  callers=("$@")
else
  callers=(.github/workflows/ci-nix.yml .github/workflows/ci-gate.yml)
fi

if [ ! -f "$wf" ]; then
  echo "check-ci-invariants: workflow not found: $wf" >&2
  exit 1
fi

for c in "${callers[@]}"; do
  if [ ! -f "$c" ]; then
    echo "check-ci-invariants: caller workflow not found: $c" >&2
    exit 1
  fi
done

# Permissions are PER JOB. A grant on one job does nothing for another job in
# the same file, so grepping the whole file is a false pass: ci-gate.yml already
# contained "actions: write" on its shared-gate job while its nix-build job had
# no block at all, and the run died at graph validation with no check-runs to
# show for it. This locates the job that calls _nix-build.yml and requires the
# scope either in that job's own block or at workflow level.
job_calling_nix_build_grants_actions_write() {
  awk '
    # Workflow-level permissions. Granting here covers every job in the file.
    /^permissions:/ { inwf = 1; next }
    inwf {
      if ($0 ~ /^[^[:space:]]/) { inwf = 0 }
      else { if ($0 ~ /actions:[[:space:]]*write/) wf = 1; next }
    }
    # A new two-space-indented key starts a new job; settle the previous one.
    /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
      if (uses && !perm && !wf) bad = 1
      uses = 0; perm = 0
    }
    # Only a real `uses:` counts. Prose naming the file in a comment does not —
    # ci-nix.yml discusses _nix-build.yml in its header, which a plain substring
    # match read as a call site and failed on.
    /^[[:space:]]*uses:[[:space:]]*.*_nix-build\.yml/ { uses = 1 }
    /actions:[[:space:]]*write/ { perm = 1 }
    END {
      if (uses && !perm && !wf) bad = 1
      exit bad
    }
  ' "$1"
}

fail=0
die() {
  echo "check-ci-invariants: $1" >&2
  fail=1
}

# The Actions cache is scoped to the branch that wrote it plus the default
# branch. `develop` IS the default branch here, so saving on `main` puts every
# entry in a scope no pull request can read. That already happened once and cost
# every PR a full cold build; the symptom was a "Cache Nix Store" step finishing
# in ~2s while multi-GB caches sat unused.
grep -q "save: \${{ github.ref == 'refs/heads/develop' }}" "$wf" ||
  die "cache 'save:' must stay pinned to refs/heads/develop (the default branch). Saving on main makes the cache unreadable to every PR."

# The timeout is the detector for closure regressions. It reads the org variable
# so the number is managed in one place.
#
# Both wrappers are load-bearing. fromJSON: every `vars.*` value is typed as a
# string while timeout-minutes demands a number, and without the conversion
# graph validation rejects the workflow — the job never starts and reports as a
# failed check with no job and no logs. `|| '15'`: an unset variable is an empty
# string, fromJSON('') errors, and fork PRs resolve org variables empty.
grep -q "timeout-minutes: \${{ fromJSON(vars.GH_ACTION_TIMEOUT_NIX || '15') }}" "$wf" ||
  die "timeout-minutes must stay \${{ fromJSON(vars.GH_ACTION_TIMEOUT_NIX || '15') }} — fromJSON is required because vars.* is a string and timeout-minutes needs a number (without it the workflow fails graph validation), and the '15' literal covers an unset variable and fork PRs."

# develop pushes are the only runs that save the cache, so cancelling them
# throws the write away. Measured before this was fixed: develop 16 success /
# 23 cancelled, while main ran 20 success / 0 cancelled.
grep -q "cancel-in-progress: \${{ github.ref != 'refs/heads/develop' }}" "$wf" ||
  die "cancel-in-progress must exempt develop — it is the only branch that saves the Nix cache."

# Sized to the measured ~4.2G non-substitutable tail (GUI apps, this repo's
# vendored Go/Rust modules), not to the org's 15G quota. Measured: restoring a
# 12G-capped store (a ~3.1G tarball) cost 8m28s of extraction against a 55s
# build. Smaller than this band risks evicting the tail itself, which forces a
# source build; larger wastes extraction time on content cache.nixos.org would
# substitute anyway. Quota headroom is no longer the binding constraint here —
# a no-cache control run did not finish in 15 minutes, so some cache is
# mandatory, but bigger is not better past the size of the tail.
grep -qE 'gc-max-store-size-macos: [5-8]G' "$wf" ||
  die "gc-max-store-size-macos must stay within 5G-8G: below risks evicting the ~4.2G non-substitutable tail (forces a source build), above wastes extraction time on content cache.nixos.org would substitute anyway."

# Without a prefix restore, any flake.lock change means a fully cold build.
grep -q 'restore-prefixes-first-match' "$wf" ||
  die "restore-prefixes-first-match must stay — without it every flake.lock change cold-builds the closure."

# Nothing deleted superseded caches, so one accumulated per flake.lock hash.
# Measured: five nix-macOS-* entries at ~3.13G each = 15.8G against a 15G org
# eviction limit. Only four fit, so every fifth lock change evicted an entry
# GitHub chose, not us, and PRs cold-started for unrelated reasons.
grep -q "purge: \${{ github.ref == 'refs/heads/develop' }}" "$wf" ||
  die "purge: must stay pinned to refs/heads/develop, matching save: — without purging, one cache accumulates per flake.lock hash until the repo exceeds its quota and GitHub evicts entries at random."

# purge-primary-key: never exempts the entry this run just wrote. Dropping it
# lets a run delete the cache it is about to reuse.
grep -q 'purge-primary-key: never' "$wf" ||
  die "purge-primary-key must stay 'never' — without it a run can purge the very cache it just saved."

# purge-created: 0 selects every matching cache; combined with the exemption
# above it keeps the newest and drops the rest. A non-zero value silently
# retains older entries and lets the quota creep back up.
grep -q 'purge-created: 0' "$wf" ||
  die "purge-created must stay 0 — any other value retains superseded caches and re-creates the quota thrash."

# Deleting a cache entry uses the Actions cache REST API, which contents:read
# cannot reach. Shipped once without this: purge failed with "Resource not
# accessible by integration" and the step STILL EXITED GREEN, so the caches kept
# accumulating with no signal anywhere except `gh cache list`.
grep -q 'actions: write' "$wf" ||
  die "the build job needs 'actions: write' or purge cannot delete caches — it fails with 'Resource not accessible by integration' while the step still reports success."

# A called workflow can never exceed its caller's grant, so the scope above must
# be granted by EVERY caller, on the specific job that does the calling.
# Omitting it fails at graph validation: startup_failure, which produces no
# check-runs at all — so a PR shows no failing check and a CLEAN merge state
# while nothing has actually run. Verification that only looks for red checks
# cannot see this; that is why it is asserted here.
for c in "${callers[@]}"; do
  job_calling_nix_build_grants_actions_write "$c" ||
    die "$c calls _nix-build.yml from a job without 'actions: write' (permissions are per-job; a grant on a different job does not count). The run will die at graph validation with startup_failure and no check-runs."
done

# develop pushes are the only runs that save the cache, so a caller that runs on
# push and defines its own concurrency group must exempt develop from
# cancellation. Scoped to push-triggered callers on purpose: ci-gate.yml is
# pull_request-only and SHOULD cancel superseded runs, so requiring the
# exemption everywhere would be wrong.
for c in "${callers[@]}"; do
  grep -q '^ *push:' "$c" || continue
  grep -q 'concurrency:' "$c" || continue
  grep -q "github.ref != 'refs/heads/develop'" "$c" ||
    die "$c runs on push and sets its own concurrency group, so it must exempt develop from cancel-in-progress — develop is the only branch that saves the Nix cache."
done

# The build budget is the pressure that keeps this job fast. Raising it converts
# a slow build into a slow build nobody is required to fix, and that has already
# happened once: the default was moved 15 -> 30 while the underlying closure
# regression went untouched. A run over budget is a closure to shrink.
grep -qE "vars.GH_ACTION_TIMEOUT_NIX \|\| '(1[0-9]|20)'" "$wf" ||
  die "the nix build timeout default must stay at or below 20 minutes — it is the only thing forcing closure regressions to get fixed rather than absorbed. A build that exceeds it is a closure to shrink, never a budget to raise."

# Closure size is this job's wall time. Both regressions that recur here produce
# a valid closure, so nothing else in CI can see them.
grep -q 'check-closure-health.sh' "$wf" ||
  die "the closure health check must stay in the build job — without it a duplicated dependency or a new multi-hundred-MB payload lands silently and every later run pays for it."

if [ "$fail" -ne 0 ]; then
  echo "check-ci-invariants: see the comments in $wf for why each invariant exists." >&2
  exit 1
fi

echo "All _nix-build.yml cost-control invariants hold."
