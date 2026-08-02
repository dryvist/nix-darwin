# Flake Update Strategy

## Overview

This repository uses automated daily flake updates via GitHub Actions workflow (`.github/workflows/deps-update-flake.yml`).

## Update Schedule

- **Daily (except Tue/Fri)**: AI-focused inputs only
- **Tuesday & Friday**: All flake inputs (including darwin, home-manager, system packages)
- **Manual trigger**: `workflow_dispatch` with optional `update_all` flag
- **Triggered sync**: `repository_dispatch` for `ai-assistant-instructions` only (fast path)

## AI-Focused Inputs (Daily Updates)

The following inputs update daily:

- `nixpkgs` (stable 25.11 channel)
- `ai-assistant-instructions` (source of truth for AI agent config)
- `claude-code-plugins` (official Anthropic)
- `claude-cookbooks` (Anthropic cookbooks)
- `claude-plugins-official` (official plugin directory)
- `jacobpevans-cc-plugins` (personal custom plugins)
- `anthropic-agent-skills` (Anthropic reusable skills)
- `superpowers-marketplace` (superpowers development system)

## Claude Code Update Philosophy

**Strategy**: Always update when available. Manually research and validate new versions.
Accept updates by default; revert only if issues discovered during testing.

### Rationale

Claude Code evolves rapidly with new features, bug fixes, and improvements. An aggressive
update approach ensures:

- Latest features and bug fixes are available immediately
- Better integration with evolving AI development workflows
- Reduced risk of stale tooling dependencies

### Workflow

1. **Automated Update**: Daily flake updates automatically include claude-code and plugins
2. **PR Creation**: GitHub Actions creates a PR with flake.lock changes
3. **CI Validation**: Automated checks validate flake structure and build
4. **Manual Review**: User reviews PR and manually validates during darwin-rebuild
5. **Accept by Default**: Merge PR unless testing reveals bugs or breaking changes
6. **Revert on Issues**: Only revert if integration problems discovered

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

- CI validates flake structure and build
- AI tool updates (including claude-code) run daily
- Claude Code philosophy: Always accept updates, manually validate, revert only if issues found
- Full dependency updates (darwin, home-manager) run Tue/Fri
