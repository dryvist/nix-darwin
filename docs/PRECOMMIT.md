# Pre-commit Hooks Guide

This guide explains how to set up and use pre-commit hooks for this nix-darwin configuration repository.

## Table of Contents

- [What Are Pre-commit Hooks?](#what-are-pre-commit-hooks)
- [Quick Start](#quick-start)
- [Tool Groups](#tool-groups)
- [Running Hooks Manually](#running-hooks-manually)
- [Common Operations](#common-operations)
- [Troubleshooting](#troubleshooting)
- [Tool Reference](#tool-reference)

## What Are Pre-commit Hooks?

Pre-commit hooks are automated checks that run **before you commit code**. They catch common issues early:

- **Formatting violations** (trailing whitespace, missing newlines)
- **Code quality problems** (unused variables, anti-patterns)
- **Security issues** (accidentally committed secrets, merge conflicts)
- **Documentation quality** (broken links, file size violations)

**Benefits:**

- Catch issues before they reach code review
- Enforce consistent code style automatically
- Prevent accidentally committing secrets or large files
- Faster CI pipelines (bad commits don't reach GitHub Actions)

## Quick Start

### Installation

Pre-commit hooks are automatically installed by Nix when you rebuild your configuration:

```bash
# Rebuild to install hooks
sudo darwin-rebuild switch --flake ~/.config/nix
```

Or manually install hooks (if not using full rebuild):

```bash
cd ~/git/nix-darwin
pre-commit install
```

Hooks are configured in `.pre-commit-config.yaml` at the repository root.

### Verify Installation

```bash
# Check if hooks are installed
ls -la .git/hooks/

# Should show: pre-commit -> <nix-store-path>/bin/pre-commit
```

### First Commit

When you make your first commit after installing hooks:

```bash
git commit -m "Your message"

# Pre-commit will run all hooks
# If any fail, commit is blocked and you see the error
```

## Tool Groups

This repository uses 4 groups of pre-commit tools, organized by purpose:

### 1. Format & Style ✏️

**Purpose:** Enforce consistent code formatting and whitespace

| Tool | What It Does | Language |
| --- | --- | --- |
| **Trailing Whitespace** | Removes trailing spaces | All files |
| **End-of-File Fixer** | Ensures files end with newline | All files |
| **Nix Formatting** | Formats Nix code to RFC style | Nix (`*.nix`) |
| **Markdown Linting** | Lints and auto-fixes markdown | Markdown (`*.md`) |

**Run:** Automatic (blocks commit if issues found)

### 2. Lint & Analysis 🔍

**Purpose:** Catch code quality issues and anti-patterns

| Tool | What It Does | Language |
| --- | --- | --- |
| **YAML Syntax** | Validates YAML structure | YAML (`*.yaml`, `*.yml`) |
| **JSON Syntax** | Validates JSON structure | JSON (`*.json`) |
| **Nix Linting (statix)** | Catches Nix anti-patterns and code smells | Nix (`*.nix`) |
| **Nix Dead Code (deadnix)** | Detects unused Nix bindings | Nix (`*.nix`) |

**Run:** Automatic (blocks commit if issues found)

**Example:** Detecting unused variables:

```bash
deadnix -L --fail .
# Output: /path/to/file.nix:42:5 unused binding 'oldVar'
```

### 3. Content Quality 📚

**Purpose:** Validate documentation integrity

| Tool | What It Does | Language |
| --- | --- | --- |
| **Lychee** | Checks links in markdown/HTML for validity | Markdown, HTML |
| **File Size Check** | Warns on large files (6KB warn, 12KB fail) | Markdown, Nix |

**Run:** Automatic (blocks commit if issues found)

**Note on Performance:** Lychee validates links asynchronously and caches results. The performance
impact is minimal compared to the value of catching broken links early. All hooks run in parallel by
default, so slowdown is offset by parallelization.

### 4. Security 🔒

**Purpose:** Prevent committing secrets and sensitive data

| Tool | What It Does |
| --- | --- |
| **Detect Private Keys** | Blocks committing SSH keys, API tokens, credentials |
| **Merge Conflict Markers** | Detects unresolved merge conflicts |
| **Large Files** | Prevents committing files over 500KB |

**Run:** Automatic (blocks commit if violations found)

## Running Hooks Manually

### All Hooks (Automatic Stage)

```bash
# Run all automatic hooks on changed files
pre-commit run

# Run all automatic hooks on all files in repo
pre-commit run --all-files
```

### Specific Hook

```bash
# Run only markdown linting
pre-commit run markdownlint-cli2

# Run only Nix formatting
pre-commit run nix-fmt-check

# Run only link checker
pre-commit run lychee
```

### Before Pushing

All hooks run automatically on commit, but you can run them manually on all files before pushing:

```bash
# Run all hooks on all files in repo
pre-commit run --all-files

# See detailed execution (useful for debugging)
pre-commit run --all-files -v

# If all pass, push
git push
```

**Note:** All hooks run in parallel by default. Hooks are executed simultaneously where possible, with each hook running on its own thread.

## Common Operations

### Auto-fix Issues

Many hooks fix issues automatically. If a hook fails:

```bash
# Markdown auto-fixes in-place
pre-commit run markdownlint-cli2 --all-files

# Nix formatting auto-fixes
pre-commit run nix-fmt-check --all-files

# Then stage and commit the fixes
git add .
git commit -m "fix: auto-fix formatting issues"
```

### Skip a Hook Temporarily

Only when you know what you're doing:

```bash
# Skip pre-commit hooks (not recommended)
git commit --no-verify -m "Your message"

# Bypassing security hooks is a security risk!
```

### Update Hooks

Hooks are managed by Nix and automatically updated when you rebuild:

```bash
# Update to latest hook versions
sudo darwin-rebuild switch --flake ~/.config/nix
```

## Troubleshooting

### "Hook not found" or "Command not found"

**Problem:** You see errors like `statix: command not found`

**Solution:** Ensure pre-commit tools are installed:

```bash
# Option 1: Full rebuild (recommended)
sudo darwin-rebuild switch --flake ~/.config/nix

# Option 2: Enter dev shell with tools
nix develop

# Option 3: Install specific tool
nix shell nixpkgs#statix -c pre-commit run nix-statix
```

### Hooks Run Slowly

**Problem:** Pre-commit takes a long time

**Solution:** Only run what you need:

```bash
# Run only changed files (faster)
pre-commit run

# All hooks run automatically; skip only if absolutely necessary
# (Note: skipping breaks your verification workflow)
```

### Lychee Says Links Are Broken (False Positives)

**Problem:** Lychee reports links as broken but they work

**Possible causes:**

- Rate limiting from the server
- Site blocks automated requests
- Temporary network issue

**Solutions:**

```bash
# Skip link checking to commit immediately (last resort)
SKIP=lychee git commit -m "message"

# Then test the links later
pre-commit run --all-files

# Or commit the fix directly
git add .
git commit -m "fix: update broken link"
```

### Mark Large File as Necessary

**Problem:** You have a large file (>12KB) that legitimately belongs in the repo

**Solution:**

Edit `.pre-commit-config.yaml` and add to `check-added-large-files`:

```yaml
args: ["--maxkb=1000", "--enforce-all"]
```

Or exclude the file pattern:

```yaml
exclude: "^vendor/|^build/"
```

### Debugging a Failed Hook

**Problem:** A hook fails but the error message isn't clear

**Solution:** Run the hook manually with verbose output:

```bash
# Run the failing hook directly
statix check .

# Or see what the hook is doing
pre-commit run nix-statix -v
```

## Tool Reference

This repository uses tools from nixpkgs. For details on each tool:

### Lychee - Link Checker

- **Homepage:** <https://github.com/lycheeverse/lychee>
- **Language:** Rust (fast, async)
- **Purpose:** Validates links in markdown and HTML
- **When to use:** Runs automatically on every commit

```bash
# Check all markdown files
lychee **/*.md

# Configure in future with .lycheeignore
```

### Statix - Nix Linter

- **Homepage:** <https://github.com/nerdypepper/statix>
- **Purpose:** Catches Nix anti-patterns
- **Examples:** Unused arguments, incorrect operators, style issues

```bash
# Show all issues with explanations
statix check .
```

### Deadnix - Nix Dead Code Detector

- **Homepage:** <https://github.com/astro/deadnix>
- **Purpose:** Finds unused variable bindings
- **Handles:** Ignores lambda parameters (`-L` flag used in pre-commit)

```bash
# Find dead code
deadnix -L .
```

### nixfmt-rfc-style - Nix Formatter

- **Homepage:** <https://github.com/NixOS/nixfmt>
- **Purpose:** Formats Nix code to RFC style
- **Note:** Auto-fixes formatting issues

```bash
# Format all Nix files
nix fmt
```

### Markdownlint-cli2 - Markdown Linter

- **Homepage:** <https://github.com/DavidAnson/markdownlint-cli2>
- **Configuration:** `.markdownlint-cli2.jsonc` at repo root
- **Note:** Auto-fixes many issues

```bash
# Check and fix markdown
markdownlint-cli2 "**/*.md"
```

## Best Practices

### 1. Fix Issues Locally, Not in PR Comments

```bash
# Before pushing
pre-commit run --all-files

# If it fails, fix locally
git add .
git commit -m "fix: address pre-commit issues"

# Then push
git push
```

### 2. Run All Checks Before Pushing

```bash
# Before git push origin branch
pre-commit run --all-files
```

### 3. Don't Skip Hooks Without Reason

```bash
# Bad: Skipping security checks
git commit --no-verify -m "Skip hooks"

# Good: Fix the issue first
git add .
git commit -m "fix: remove accidentally added secrets"
```

### 4. Understand Hook Failures

Don't just blindly fix errors - understand what each hook is checking:

```bash
# If statix complains, read the error
statix check . 2>&1 | head -20

# If deadnix flags a binding, decide if it's really unused
grep -n "oldVar" src/**/*.nix
```

## Related Documentation

- [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute
- [CLAUDE.md](../CLAUDE.md) - AI agent instructions
- [SETUP.md](../SETUP.md) - Initial setup
- `modules/precommit-tools/default.nix` - Tool definitions and metadata

## Questions?

If a hook is confusing or seems wrong:

1. Check the tool's documentation (links in Tool Reference above)
2. Run the tool manually to see detailed output
3. Open an issue with: the hook name, your file, and the exact error message
