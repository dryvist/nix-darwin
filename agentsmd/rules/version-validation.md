# AI Agent Version Selection Rules

**Purpose**: Prevent AI agents from suggesting or pinning outdated package versions.

**Created**: 2026-01-02 (in response to nodejs 388 days old, crush 29 versions behind)

## Mandatory Requirements

When suggesting or pinning package versions, AI agents MUST:

### 1. Research Version Currency BEFORE Suggesting

- Check npm registry, GitHub releases, or package homepage for latest version
- Compare suggested version age against current date
- If version is >30 days old, explicitly state age and confirm with user

**Tools to use**:

- npm: `npm view <package> version` or `npm view <package> time`
- GitHub: Check releases page or use GitHub API
- Nix: `nix search nixpkgs <package>` then verify upstream

### 2. Avoid Date-Based Assumptions

- **NEVER assume knowledge of events after April 2024** (Claude's training cutoff)
- ALWAYS use actual current date when evaluating version freshness
- If unsure of current date, ask user to confirm

**Why this matters**: Claude Sonnet suggested crush without version pin,
human pinned to v0.1.1 (released early 2024) thinking it was recent, but
latest was v0.30.0.

### 3. Understand Validation Triggers

**Pre-commit hook**: `scripts/validate-package-freshness.sh`

- Runs on every commit (via `.pre-commit-config.yaml`)
- FAILS if critical packages >30 days old
- FAILS if any package >90 days old

**CI check**: `.github/workflows/ci-package-staleness.yml`

- Runs on every PR affecting `flake.lock`
- Blocks merge unless `skip-version-check` label added
- Posts comment with staleness report

**Renovate Bot**: `.github/renovate.json5`

- Auto-creates PRs for outdated packages within 24 hours
- Groups updates by criticality (critical Mon/Thu, AI tools Sun/Wed/Fri, npm Mon)
- Auto-merges patch + minor updates
- Requires human review for major updates

### 4. Follow Exemption Procedure

If package MUST be pinned to old version (broken nixpkgs, compatibility):

1. Document reason in code comment with date and justification
2. Add to `EXEMPT_PACKAGES` array in `scripts/validate-package-freshness.sh`
3. Create GitHub issue to track when exemption can be removed
4. Re-evaluate exemption quarterly

**Example exemption**:

```nix
# EXEMPTED: 2026-01-02 - nixpkgs version has broken twisted dependency
# TODO: Remove exemption when nixpkgs #12345 is resolved
# See: https://github.com/NixOS/nixpkgs/issues/12345
(writeShellScriptBin "package" ''
  exec ${bun}/bin/bunx --bun package@1.0.0 "$@"
'')
```

## Examples

### ✅ CORRECT Version Selection

```nix
# GOOD: Researched latest version before suggesting
# npm view @charmbracelet/crush version → 0.30.0 (released Dec 2025)
# Age verified at time of suggestion: within 30-day freshness requirement
(writeShellScriptBin "crush" ''
  exec ${bun}/bin/bunx --bun @charmbracelet/crush@0.30.0 "$@"
'')
```

### ❌ INCORRECT Version Selection

```nix
# BAD: Pinned to v0.1.1 without research (29 versions behind!)
# Latest is v0.30.0 - this version is 365+ days old
# This will FAIL pre-commit validation
(writeShellScriptBin "crush" ''
  exec ${bun}/bin/bunx --bun @charmbracelet/crush@0.1.1 "$@"
'')
```

## Consequences of Suggesting Outdated Versions

1. **Pre-commit hook blocks commit** with error:

   ```text
   ✗ FAIL: @charmbracelet/crush@0.1.1 is 365 days old (limit: 90 days)
   ```

2. **CI blocks PR merge** with comment showing staleness report

3. **Manual override required** - must add to exemption list with justification

4. **User trust decreases** - AI appears to make uninformed suggestions

## Research Workflow

**Before suggesting any package version**:

1. **Check package registry**:

   ```bash
   npm view <package> version     # Get latest version
   npm view <package> time        # Get release dates
   ```

2. **Verify release date**:
   - If latest release >30 days ago, mention age to user
   - If suggested version >30 days old, explain why (compatibility, stability, etc.)

3. **Check for major version changes**:
   - If pinning to old major version, state reason (breaking changes, compatibility)
   - Link to changelog or migration guide

4. **Document decision**:
   - Add comment explaining version choice
   - Include date and reasoning
   - Link to upstream release notes if relevant

## Remember

**Research first, pin second.**

Version currency prevents:

- Security vulnerabilities (CVEs in old versions)
- Missing bug fixes and improvements
- Compatibility issues with modern tooling
- Technical debt from stale dependencies

**When in doubt, ask the user** which version to use rather than guessing or assuming.
