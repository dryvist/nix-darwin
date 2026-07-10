# Nix Dependencies Synchronization

## Rule: Always Keep nix-darwin in Sync with Latest JacobPEvans/nix-* Repos

**Scope**: All flake inputs from `github:JacobPEvans/nix-*`

**Current inputs**:
- `nix-ai` — AI CLI ecosystem (Claude, Gemini, Copilot, MCP)
- `nix-home` — Cross-platform home-manager modules (git, zsh, vscode, monitoring)
- `ai-assistant-instructions` — Shared AI assistant configurations (rules, skills)
- `claude-code-plugins` — Claude Code plugin marketplace

**Private repos** (explicitly excluded from sync rule):
- Any repositories marked as private in GitHub are completely ignored
- Private repos are not referenced in this rule or any sync processes

## Enforcement

### Automated (CI)

- **Renovate** — Daily at 7am ET, polls for new versions. JacobPEvans inputs are in
  GROUP 1 (critical infrastructure) and GROUP 2 (AI tools) in `renovate.json5`.
- **`deps-update-flake.yml`** — Manual dispatch only (see *Immediate* below); bumps
  JacobPEvans flake inputs on demand. Third-party flake input updates are handled by
  Renovate, not this workflow.

### Immediate (after shipping upstream changes)

When you've just merged changes in nix-home, nix-ai, or another JacobPEvans repo and
need nix-darwin to pick them up immediately — don't wait for Renovate:

```bash
gh workflow run deps-update-flake.yml --repo JacobPEvans/nix-darwin
```

This triggers `.github/workflows/deps-update-flake.yml` which:
1. Runs `nix flake update nix-home nix-ai ai-assistant-instructions claude-code-plugins`
2. Opens a PR with the updated `flake.lock`
3. CI validates, then auto-merge (via org Renovate preset) handles the rest

### Manual (full rebuild)

**When to use**: Regular maintenance, or when you also want to validate with a local rebuild.

```bash
/flake-rebuild
```

This command:
1. Syncs main branch
2. Creates feature branch `chore/flake-update-YYYY-MM-DD`
3. Runs `nix flake update` to fetch latest inputs from all JacobPEvans/nix-* repos
4. Runs quality checks (fmt, statix, deadnix, flake check)
5. Rebuilds system to validate all changes
6. Creates PR with auto-merge enabled

## Rationale

**Why**: nix-ai and nix-home contain critical security patches, bug fixes, and new features
that affect system stability and configuration management. Staying current ensures the
system benefits from the latest improvements across the entire nix-* ecosystem.

**Why auto-merge**: Dependency updates are non-breaking by design. The flake.lock is
a lock file; semantic versioning is enforced by release-please. If an update breaks
the build, the CI gate catches it before merge.

## Related Files

- `.github/workflows/deps-update-flake.yml` — Manual dispatch: bumps JacobPEvans flake inputs on demand
- `renovate.json5` — Renovate config with package groups and schedules
- `flake.nix` — Input declarations
- `flake.lock` — Current pinned versions (auto-updated)
- `/flake-rebuild` command — Manual full update + rebuild trigger
