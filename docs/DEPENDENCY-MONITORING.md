# Dependency Monitoring System

How dependency updates are maintained in this repository.

## Shared policy

Renovate extends `github>JacobPEvans/.github:renovate-nix`. The shared preset
owns update cadence, grouping, release-age policy, and auto-merge behavior.
`renovate.json5` keeps only this repository's custom managers and the guard
for cluster-critical files.

## flake.lock

The Renovate Nix preset owns `flake.lock` maintenance. Weekend lock-file
maintenance opens a consolidated update PR, which goes through this
repository's normal CI and merge rules. Do not add a second lock-writing
workflow. When changing an input declaration in `flake.nix`, include a matching
`nix flake lock` update.

The preset's Nix manager also handles Nix-specific updates. The configured
`nixpkgs` channel reference is intentionally stable; lock-file maintenance
refreshes its locked revision when the channel advances.

## Repository-specific Renovate configuration

Renovate still owns the following local configuration:

- The Cribl Edge release pin in `hosts/common/cribl.nix`.
- The macOS base VM image digest in `modules/darwin/apps/macos-vm-runner.nix`.
- The annotated version-pin manager for Nix files, except the cluster-critical
  files excluded by the local package rule.

## References

- [Renovate configuration](../renovate.json5)
- [Flake inputs](../flake.nix)
- [AI review workflow](../.github/workflows/review-deps.yml)
- [Package staleness check](../.github/workflows/ci-package-staleness.yml)
- [Handling Renovate PRs](../RUNBOOK.md#handling-renovate-prs)
- [Troubleshooting Renovate](../RUNBOOK.md#troubleshooting-renovate)
