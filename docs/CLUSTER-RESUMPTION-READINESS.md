# Cluster resumption readiness — SUPERSEDED

This was a point-in-time (2026-07-24) read-only assessment of both Macs. Its
findings drove fixes that have since shipped: the readiness latch's warm
re-check, the shared serving restore, the PD-debt ledger, link-prep self-heal,
the generation-parity gate, and the standalone lease. Several statements here
became false as those landed ("no post-start hang detection", "a failed
restore is swallowed", "nix-ai#1384 not converged"), so keeping the text would
force a reader to reconcile two pages.

**The current truth lives in one place:** nix-ai
[`docs/runbooks/cluster-link-truths.md`](https://github.com/dryvist/nix-ai/blob/develop/docs/runbooks/cluster-link-truths.md)
(every rule, what the automation enforces, the verified reboot recovery path)
and
[`docs/runbooks/cluster-lifecycle.md`](https://github.com/dryvist/nix-ai/blob/develop/docs/runbooks/cluster-lifecycle.md)
(procedure). One durable fact from this assessment is kept there and in
[CLUSTER_MODE.md](CLUSTER_MODE.md): the clustered and standalone wired
ceilings are the same value by config derivation, so ceiling flips are no-ops
and can prove nothing.

The full original assessment is in git history of this file.
