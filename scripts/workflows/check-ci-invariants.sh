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
# Usage: check-ci-invariants.sh [path/to/_nix-build.yml]

set -euo pipefail

wf="${1:-.github/workflows/_nix-build.yml}"

if [ ! -f "$wf" ]; then
  echo "check-ci-invariants: workflow not found: $wf" >&2
  exit 1
fi

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

# The org caps the cache size eviction limit at 15G and this repo sits at that
# ceiling. Smaller values evict exactly the expensive, non-substitutable tail
# the cache exists to hold; larger risks evicting the repo's other caches.
grep -qE 'gc-max-store-size-macos: 1[0-4]G' "$wf" ||
  die "gc-max-store-size-macos must stay within 10G-14G: below wastes the org's 15G quota, at/above 15G risks evicting the repo's other caches."

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

if [ "$fail" -ne 0 ]; then
  echo "check-ci-invariants: see the comments in $wf for why each invariant exists." >&2
  exit 1
fi

echo "All _nix-build.yml cost-control invariants hold."
