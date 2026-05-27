# GitHub Actions Workflows

CI/CD workflows for this nix-darwin configuration repository.

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    REUSABLE WORKFLOWS                       │
│         (Implementation - workflow_call triggers)           │
├─────────────────────────────────────────────────────────────┤
│  _nix-build.yml     │ macOS nix build, format, symlinks    │
│  _nix-validate.yml  │ Linux flake check                    │
│  _markdown-lint.yml │ markdownlint                         │
│  _claude-settings.yml │ Claude settings schema validation  │
│  _file-size.yml     │ File size enforcement                │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│      ci-gate.yml        │     │   Standalone Workflows  │
│   (PR orchestrator)     │     │    (Push to main)       │
├─────────────────────────┤     ├─────────────────────────┤
│ • Detects file changes  │     │ ci-nix.yml              │
│ • Calls reusable flows  │     │ ci-validate.yml         │
│ • Merge Gate aggregates │     │ ci-markdownlint.yml     │
└─────────────────────────┘     │ ci-file-length.yml      │
                                └─────────────────────────┘
```

## Merge Gatekeeper Framework

### The Problem

GitHub branch protection only supports "always required" OR "not required" checks.
When path-filtered workflows don't run, the check stays "pending" forever, blocking auto-merge.

### The Solution: CI Gate

The `ci-gate.yml` workflow implements the **Merge Gatekeeper Pattern**:

1. **Always triggers** on all PRs (no path filters at workflow level)
2. **Detects changes** using `dorny/paths-filter` to categorize modified files
3. **Calls reusable workflows** conditionally based on what changed
4. **Skipped = Success** - GitHub treats skipped jobs as successful for dependencies
5. **Merge Gate** - Final job aggregates all results

### Branch Protection Setup

Set **only** `Merge Gate` as a required check:

```text
Repository Settings → Rules → Rulesets → main
  → Require status checks to pass
  → Add: "Merge Gate"
```

## Adding New Checks

### 1. Create Reusable Workflow

Create `_your-check.yml` with `workflow_call` trigger:

```yaml
# .github/workflows/_your-check.yml
name: _your-check

on:
  workflow_call:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      # ... your check implementation
```

### 2. Add to CI Gate

In `ci-gate.yml`:

```yaml
# Add filter pattern
changes:
  steps:
    - uses: dorny/paths-filter@v3
      with:
        filters: |
          your-check:
            - 'path/to/files/**'

# Add conditional job
your-check:
  name: Your Check
  needs: changes
  if: needs.changes.outputs.your-check == 'true'
  uses: ./.github/workflows/_your-check.yml

# Add to gate
gate:
  needs: [..., your-check]
  steps:
    - uses: re-actors/alls-green@release/v1
      with:
        allowed-skips: ..., your-check
```

### 3. (Optional) Add Standalone Caller

For push-to-main visibility:

```yaml
# .github/workflows/ci-your-check.yml
name: Your Check

on:
  push:
    branches: [main]
    paths: ['path/to/files/**']

jobs:
  check:
    uses: ./.github/workflows/_your-check.yml
```

## Workflow Reference

### Reusable Workflows (Implementation)

| Workflow | Purpose | Runner |
| --- | --- | --- |
| `_nix-build.yml` | Nix format, build, symlink verify | macOS |
| `_nix-validate.yml` | Flake lint and check | Linux |
| `_markdown-lint.yml` | Markdown formatting | Linux |
| `_claude-settings.yml` | Claude settings schema | Linux |
| `_file-size.yml` | File size limits | Linux |

### CI Gate (PR Orchestrator)

| Check | Triggers On |
| --- | --- |
| Nix Build | `**.nix`, `flake.lock`, `modules/**`, `scripts/**` |
| Nix Validate | `**.nix`, `flake.lock`, `modules/**`, `scripts/**` |
| Markdown Lint | `**.md`, `.markdownlint.*` |
| Claude Settings | `.claude/**` |
| File Size | `**.nix`, `**.md` |

### Other Workflows

| Workflow | Purpose |
| --- | --- |
| `review-code.yml` | Claude Code PR review |
| `review-deps.yml` | Dependency update reviews |
| `deps-update-flake.yml` | Unified flake.lock updates (schedule + instant sync) |

## Configuration

### Required Secrets

| Secret | Required By |
| --- | --- |
| `CLAUDE_OAUTH_TOKEN` | `review-code.yml` |

Note: `deps-update-flake.yml` uses only `GITHUB_TOKEN` (no additional secrets needed).

### Auto-Merge Compatibility

With the Merge Gatekeeper pattern:

1. Enable auto-merge on PRs
2. `Merge Gate` always reports a status (pass/fail)
3. Skipped checks don't block merge
4. Failed checks correctly block merge
