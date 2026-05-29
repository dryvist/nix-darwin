# Dependency Monitoring System

Automated dependency monitoring and update system for nix-darwin configuration.

## Overview

This repository uses a **complementary dependency update strategy** combining:

1. **Renovate Bot** (primary) - Automated dependency PRs with grouping and auto-merge
2. **Custom Workflow** (fallback) - Manual flake updates ONLY when Renovate hasn't acted

## Update Automation Layers

| Layer | Role | What Updates | When | Auto-merge |
| --- | --- | --- | --- | --- |
| **Renovate Bot** (Primary) | Proactive updates | Critical infra, AI tools, npm | Daily 7am (critical/AI), Mon (npm) | Yes (varies by group) |
| **Custom Workflow** (Fallback) | Safety net | All inputs IF no Renovate PR exists | Tue/Fri (all), daily (AI-focused) | No |
| **repository_dispatch** | Rapid response | ai-assistant-instructions only | Instant (on push to source) | No |
| **workflow_dispatch** | Manual | Any inputs | On demand | No |

**Key relationship:** Custom Workflow checks if a Renovate PR exists and skips if one does, preventing duplicate update attempts.

## Renovate Bot (Primary Automation)

**Configuration**: `.github/renovate.json5`

Renovate Bot is a GitHub App that automatically creates pull requests for dependency updates.
It provides native Nix flake support and can scan arbitrary files for package versions.

### Why Renovate?

**Chosen over Dependabot** because:

- ✅ Native Nix flake support (updates `flake.lock`)
- ✅ Custom regex managers (scans bunx wrappers in `.nix` files)
- ✅ Flexible grouping (by package type, criticality, schedule)
- ✅ Auto-merge policies (configurable per group, including all-types for trusted inputs)
- ✅ Node.js LTS constraints (prevents non-LTS versions)
- ✅ Signed commits via GitHub App

**What Renovate monitors:**

1. **Nix flake inputs** - via native `nix` manager
2. **Bunx wrappers** - via regex manager scanning `.nix` files
3. **npm package versions** - in comments and wrapper scripts

### Update Schedule by Package Group

| Group | Packages | Schedule | Auto-merge |
| --- | --- | --- | --- |
| **Critical Infrastructure** | nixpkgs, darwin, home-manager, ai-assistant-instructions | Daily after 7am | No (manual review) |
| **AI Tools** | claude-code-plugins, nix-ai, anthropics, etc. | Daily after 7am | Yes (all types) |
| **npm Packages** | cclint, chatgpt-cli, gh-copilot | Monday 10pm | Yes (patch/minor) |

**Auto-merge policy:**

- **Patch updates** (1.2.3 → 1.2.4): Auto-merge after CI passes
- **Minor updates** (1.2.3 → 1.3.0): Auto-merge after CI passes
- **Major updates** (1.2.3 → 2.0.0): Manual review required
  - Exception: **AI Tools** group auto-merges all update types (all packages are JacobPEvans-owned or trusted)

### Node.js Version Constraints

Renovate is configured to **only track LTS releases** for Node.js:

```json5
{
  "matchPackageNames": ["nodejs"],
  "allowedVersions": "20.x || 22.x",  // LTS versions only
  "schedule": ["before 3am on Monday", "before 3am on Thursday"]
}
```

This prevents upgrading to non-LTS "Current" releases.

### How Renovate PRs Work

1. **Detection**: Renovate checks for updates on schedule or when triggered
2. **Grouping**: Updates are grouped by package type (critical, AI tools, npm)
3. **PR Creation**: Creates PR with:
   - Descriptive title (e.g., "chore(deps): update critical-infrastructure group")
   - Changelog links and release notes
   - Verified signature via Renovate App
4. **CI Validation**: PR triggers:
   - `nix flake check` (syntax and evaluation)
   - Package staleness check (`.github/workflows/ci-package-staleness.yml`)
   - AI review (`.github/workflows/review-deps.yml`)
5. **Auto-merge** (if enabled):
   - Waits for all CI checks to pass
   - Requires PR to be up-to-date with base branch
   - Auto-merges based on group policy (patch/minor for most, all types for AI Tools)
6. **Manual Review** (when required):
   - User reviews changelog and breaking changes
   - Tests locally if needed: `nix flake update <input> && darwin-rebuild build`
   - Approves and merges manually

### Renovate Dashboard

Renovate creates a **Dependency Dashboard** issue that shows:

- Pending updates (waiting for schedule)
- Rate-limited updates (too many concurrent PRs)
- Conflicted PRs (need rebase)
- Manually approved updates

**Access**: Check for issue titled "Dependency Dashboard" with label `dependencies`.

### Installation (Required - Manual)

**Renovate must be installed as a GitHub App:**

1. Navigate to <https://github.com/apps/renovate>
2. Click "Configure" → Select repository
3. Grant permissions:
   - Read/write: code, pull requests, issues
   - Read: workflows, actions
4. Enable signed commits (automatic via Renovate App)

**Verification:**

```bash
# Check for Renovate PRs
gh pr list --search "author:app/renovate"

# View Dependency Dashboard
gh issue list --search "Dependency Dashboard in:title"
```

## Custom Workflow (Fallback)

**Workflow**: `.github/workflows/deps-update-flake.yml`

A single workflow handles all flake input updates with verified commit signatures.

### Update Strategy

| Day | Inputs Updated |
| --- | --- |
| Monday, Wednesday, Thursday, Saturday, Sunday | AI-focused inputs (9 total) |
| Tuesday, Friday | ALL flake inputs |
| repository_dispatch event | ai-assistant-instructions only (fast sync) |
| Manual with `update_all: true` | ALL flake inputs |

### AI-Focused Inputs (Daily)

Updated daily at noon UTC:

- `nixpkgs`
- `ai-assistant-instructions`
- `claude-code-plugins`
- `claude-cookbooks`
- `claude-plugins-official`
- `anthropic-agent-skills`
- `superpowers-marketplace`

### Full Updates (Tue/Fri)

Includes all AI-focused inputs plus:

- `darwin`
- `home-manager`
- All other flake inputs

### Verified Commit Signatures

All commits are signed via GitHub's REST API using `peter-evans/create-pull-request`
with `sign-commits: true`. This produces verified signatures as `github-actions[bot]`.

**Key benefit**: No additional secrets required - uses built-in `GITHUB_TOKEN`.

### Manual Trigger

```bash
# Update based on day of week (AI-focused or all)
gh workflow run deps-update-flake.yml

# Force update ALL inputs regardless of day
gh workflow run deps-update-flake.yml -f update_all=true
```

## Instant Sync: ai-assistant-instructions

When the `ai-assistant-instructions` repository is updated, a `repository_dispatch`
event triggers an immediate sync of just that input.

### How It Works

1. Push to `ai-assistant-instructions` main branch triggers repository_dispatch
2. `deps-update-flake.yml` receives the `ai-instructions-updated` event
3. Only `ai-assistant-instructions` input is updated (fast sync)
4. PR created with verified signature

## References

- [GitHub Actions Workflows](../.github/workflows/)
- [Nix Flake Inputs](../flake.nix)
- [AI Review Workflow](../.github/workflows/review-deps.yml)
- [Repository Dispatch Documentation](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#repository_dispatch)
- [Renovate PR Procedures](../RUNBOOK.md#handling-renovate-prs)
- [Package Staleness Troubleshooting](../RUNBOOK.md#troubleshooting-renovate)
