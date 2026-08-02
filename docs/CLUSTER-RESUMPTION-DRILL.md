# Cluster resumption drill — SUPERSEDED

This was the 2026-07-24 plug/unplug acceptance-test plan. Its acceptance bar
and abort conditions are now enforced or documented canonically, so the drill
no longer needs a separate script a human follows:

- Bring-up and safe-unplug are `cluster-join` / `cluster-detach`, each of
  which verifies its own postconditions — procedure in nix-ai
  [`docs/runbooks/cluster-lifecycle.md`](https://github.com/dryvist/nix-ai/blob/develop/docs/runbooks/cluster-lifecycle.md).
- The acceptance rule (a real completion returning coherent text, never a
  `/v1/models` 200), the PD-guard abort condition, the memory thresholds and
  every observation trap the drill warned about live in nix-ai
  [`docs/runbooks/cluster-link-truths.md`](https://github.com/dryvist/nix-ai/blob/develop/docs/runbooks/cluster-link-truths.md).
- The unattended path the drill existed to prove (plug in → clustered,
  unplug → standalone, reboot → recovered) is watcher-enforced and the reboot
  recovery leg is verified end-to-end — truths page §7.

The full original drill is in git history of this file.
