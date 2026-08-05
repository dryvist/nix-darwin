# Dependency Monitoring System

How dependencies are kept current in this repository, and which mechanism owns
which file.

## Two mechanisms, no overlap

| Mechanism | Owns | Never touches |
| --- | --- | --- |
| `.github/workflows/deps-flake-lock.yml` | `flake.lock`, entirely | anything else |
| Renovate Bot | GitHub Actions pins, `# renovate:`-annotated version strings in `.nix` files, npm | `flake.lock` |

The boundary is absolute and deliberate. **`flake.lock` has exactly one
writer.** Renovate's `nix` manager is disabled org-wide in
`dryvist/.github`'s `renovate-nix.json`, so nothing else can open a competing
lock PR.

## flake.lock: one workflow, one branch, one pull request

`deps-flake-lock.yml` calls the shared
`dryvist/.github/.github/workflows/_update-flake-lock.yml`, which runs a bare
`nix flake update` — every root input moves together.

| Trigger | When |
| --- | --- |
| `schedule` | Thursday 18:00 UTC (`11 18 * * 4`; the minute differs per nix repo) |
| `repository_dispatch` | An upstream dryvist repo cuts a release (`update-flake-input`) |
| `workflow_dispatch` | On demand: `gh workflow run deps-flake-lock.yml` |

All three land on the branch **`chore/flake-lock`**, so this repository never
carries more than one open flake pull request. A dispatch arriving while that
pull request is open re-runs the relock from the base branch and amends it, so
no earlier bump is lost.

### Auto-merge is gated on nixpkgs

- **No `nixpkgs*` input moved** — the pull request auto-merges once CI is green.
  This keeps release propagation hands-off.
- **A `nixpkgs*` input moved** — auto-merge is withheld and the pull request is
  labelled `needs-review`. This repository configures live machines, and a
  channel jump rebuilds the world.

### Why Renovate cannot do this

Renovate advances a flake input when the input's **reference** changes.
`nixpkgs.url` is pinned to `nixpkgs-26.05-darwin`, a moving channel branch whose
reference never changes — new commits simply land on the same branch. Renovate
has nothing to diff, so the locked revision would freeze permanently.

Advancing it requires `nix flake update`, which in Renovate terms is
`lockFileMaintenance`; that is disabled for nix org-wide because it resolves to
absolute-latest, ignores `minimumReleaseAge`, and once looped roughly 60 pull
requests a week on this repository.

A `minimumReleaseAge: "2 days"` rule labelled "for nixpkgs-darwin Hydra eval
lag" used to sit in `renovate.json5`. It was removed on 2026-08-05 because it
never once fired — for the same reason: there was no reference change for the
age gate to hold back.

### Hydra alignment

The shared workflow compares the newly locked revision against
`channels.nixos.org/<ref>/git-revision` and emits a **warning** on mismatch. It
is advisory, never a hard failure, because the channel URL can lag briefly after
a Hydra evaluation. A pin that drifts off the evaluated channel head loses
binary-cache coverage, which is what makes staleness expensive rather than
cosmetic.

## Renovate Bot

**Configuration**: `renovate.json5`, extending `local>dryvist/.github:renovate-nix`.

Tier taxonomy, cadence, and auto-merge policy are canonical at
<https://docs.jacobpevans.com/infrastructure/cicd/dependency-automation>.
Pull-request creation runs in two weekly windows, Monday ~05:00 America/New_York
and Thursday 18:00 UTC.

Renovate still owns, in this repository:

- GitHub Actions version and digest pins.
- The Cribl Edge version pin in `packages/cribl-edge.nix`, via a custom
  datasource.
- Any `# renovate:`-annotated version string in a `.nix` file. This is a
  separate mechanism from the `nix` manager and is unaffected by that manager
  being off — it edits version strings, never `flake.lock`.

Cluster-critical files (`hosts/common/cluster-wired-limit.nix`,
`hosts/common/cluster-quiesce.nix`, `modules/darwin/cluster-link-prep.nix`) are
excluded from Renovate entirely: wired-memory ceilings and static link
configuration must only ever change through a deliberate, supervised pull
request.

Renovate publishes a **Dependency Dashboard** issue listing pending,
rate-limited, and conflicted updates:

```bash
gh issue list --search "Dependency Dashboard in:title"
gh pr list --search "author:app/renovate"
```

## References

- [`deps-flake-lock.yml`](../.github/workflows/deps-flake-lock.yml)
- [Flake inputs](../flake.nix)
- [AI review workflow](../.github/workflows/review-deps.yml)
- [Package staleness check](../.github/workflows/ci-package-staleness.yml)
- [Handling Renovate PRs](../RUNBOOK.md#handling-renovate-prs)
- [Troubleshooting Renovate](../RUNBOOK.md#troubleshooting-renovate)
- [repository_dispatch](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#repository_dispatch)
