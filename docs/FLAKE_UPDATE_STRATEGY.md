# Flake Update Strategy

## Overview

`flake.lock` has one writer: `.github/workflows/deps-flake-lock.yml`. The workflow calls the shared
`dryvist/.github/.github/workflows/_update-flake-lock.yml` reusable workflow. Every run writes to the
branch `chore/flake-lock`, so this repository has at most one open flake pull request.

## Triggers

| Trigger | Relocks |
| --- | --- |
| `schedule` (Thursday 18:00 UTC) | Every input except dryvist inputs |
| `repository_dispatch` (`update-flake-input`) | The named dryvist input only |
| `workflow_dispatch` | On demand: `gh workflow run deps-flake-lock.yml` |

## Dryvist Inputs

Each dryvist input names a floating major tag: `github:dryvist/<repo>?ref=vN`.
`flake.lock` holds the exact revision. A bump is a pull request.

| Bump | Merge |
| --- | --- |
| Patch | Auto-merges after the Merge Gate is green |
| Minor | A person merges it. It never auto-merges. |
| Major | A person merges it. It never auto-merges. |

A pull request that contains a minor or major dryvist bump does not auto-merge.

## nixpkgs

A `nixpkgs*` move never auto-merges. The pull request is labelled `needs-review`.

## Claude Code Update Philosophy

**Strategy**: Always update when available. Manually research and validate new versions.
Accept updates by default; revert only if issues discovered during testing.

### Workflow

1. **Update**: The weekly relock includes the third-party `claude-code` input.
2. **PR Creation**: The relock workflow opens a pull request with `flake.lock` changes.
3. **CI Validation**: Automated checks validate flake structure and build.
4. **Manual Review**: User reviews the PR and validates during darwin-rebuild.
5. **Accept by Default**: Merge the PR unless testing reveals bugs or breaking changes.
6. **Revert on Issues**: Revert only if integration problems are found.

## Validation Gates

Before accepting Claude Code updates:

```bash
# Validate flake structure
nix flake check

# Rebuild darwin system
sudo darwin-rebuild switch --flake .

# Test claude-code functionality
claude --version
```

## PR Review Notes

- CI validates flake structure and build.
- The weekly relock includes `claude-code`. Dryvist inputs are excluded from it.
- A dryvist patch bump auto-merges. A minor or major bump waits for a person.
- A `nixpkgs*` move waits for a person.
