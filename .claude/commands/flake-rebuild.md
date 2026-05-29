---
description: Update all flake inputs and rebuild nix-darwin with issue reporting
model: haiku
allowed-tools: Read, Grep, Glob, Bash(nix flake *), Bash(nix fmt), Bash(statix *), Bash(deadnix), Bash(git *), Bash(gh *), Bash(darwin-rebuild *), Bash(sudo darwin-rebuild *), AskUserQuestion
---

# Flake Rebuild

**This is an EXECUTION command. When invoked, EXECUTE all steps below. Do not treat this as documentation to edit.**

Update all flake inputs, rebuild nix-darwin, and create a PR. Reports any warnings or errors encountered.

If the user passes additional arguments (e.g. "also update X" or "fix Y"), handle those AS PART OF the rebuild workflow — do not skip the rebuild itself.

**IMPORTANT**: This command uses GitHub auto-merge. The PR will automatically merge when all required status checks pass.

## Critical Rules

1. **ALWAYS EXECUTE THE REBUILD** - This command exists to run, not to be read
2. **NEVER commit to main** - Always create or switch to a feature branch FIRST
3. **NEVER manually merge** - Use `gh pr merge --auto` to enable auto-merge

## Repository Structure

This repo uses a bare git repo with worktrees:

- `${GIT_HOME_PUBLIC}/nix-darwin/` - bare repo (do not cd here directly)
- `${GIT_HOME_PUBLIC}/nix-darwin/main/` - main branch worktree
- `${GIT_HOME_PUBLIC}/nix-darwin/<branch-name>/` - feature worktrees

## Steps

### 1. Sync Main Worktree First

**IMPORTANT**: Update the main worktree before starting:

```bash
cd ${GIT_HOME_PUBLIC}/nix-darwin/main
git fetch origin
git pull origin main
git status
```

If there are uncommitted changes, **STOP** and report to the user.

### 2. Create or Switch to Feature Worktree

Branch/worktree name format: `chore/flake-update-YYYY-MM-DD` (replace with today's date)

Check if worktree already exists, otherwise create it:

```bash
cd ${GIT_HOME_PUBLIC}/nix-darwin
# Check if worktree exists
if [ -d "chore/flake-update-YYYY-MM-DD" ]; then
  cd chore/flake-update-YYYY-MM-DD
  git pull origin main  # Update with latest main
else
  git worktree add chore/flake-update-YYYY-MM-DD -b chore/flake-update-YYYY-MM-DD origin/main
  cd chore/flake-update-YYYY-MM-DD
fi
```

### Security Note

This command is the **approved method** for updating flake inputs. It enforces:
- Feature branch isolation (never commits to main)
- Full quality validation (fmt, statix, deadnix, flake check, darwin-rebuild)
- CI gating via auto-merge (all required status checks must pass)

**WARNING**: Running raw `nix flake update && sudo darwin-rebuild switch --flake .` outside this command
bypasses all security checks. Always use `/flake-rebuild` for flake updates.

### 3. Update ALL Flake Inputs

**IMPORTANT**: Update the root flake AND all shell/module flakes throughout the repository.

Use the centralized update script to avoid DRY violations:

```bash
./scripts/update-all-flakes.sh
```

**Script reference**: See `scripts/update-all-flakes.sh` in the repository root.

The script updates:

- Root flake.lock (darwin, home-manager, nixpkgs, AI tools)
- Shell environment flakes (shells/**/flake.lock)
- Host-specific flakes (hosts/**/flake.lock)

**On failure**: Report the error and stop.

### 4. Check for Changes

```bash
git status --short
```

- If **no changes**: Report "All flake inputs already up to date" and **STOP**.
- If **changes detected**: Continue to step 5.

### 5. Commit the Updates

```bash
# Add all modified and new flake.lock files
git add */flake.lock flake.lock 2>/dev/null || true
git add shells/*/flake.lock hosts/*/flake.lock 2>/dev/null || true

# Create a descriptive commit message
git commit -m "chore(deps): update all flake inputs

Updated nixpkgs and other inputs across:
- Root flake
- Shell environments
- Host configurations"
```

### 6. Run Quality Checks and Rebuild

Run each check below **with full output visible** (do NOT pipe to `/dev/null`).
For any check that reports issues, **briefly investigate**: read the output,
identify which files/lines are affected, and note the likely cause.

Run these checks in order:

1. **Format check**: `nix fmt` (prints which files it reformats)
   - Note any files that were changed
2. **Static analysis**: `statix check`
   - Note any warnings with file:line references
3. **Dead code detection**: `deadnix`
   - Note any unused bindings with file:line references
4. **Flake validation**: `nix flake check`
   - If this fails, read the error output and identify the root cause (eval error, missing input, type mismatch, etc.)
5. **Rebuild**: `sudo darwin-rebuild switch --flake .`
   - If this fails, read the last 50 lines of output and identify the failing derivation or activation step

**Categorize each finding as:**

- **Critical** — blocks the build or flake check (must fix before merge)
- **Warning** — non-fatal lint/format issue (CI will also catch these)
- **Info** — unexpected but harmless output worth noting

**Always proceed to Step 7** regardless of results.

### 7. Present Diagnostic Summary (If Issues Found)

**If all checks passed with no issues**: Skip this step and proceed directly to Step 8.

**If any issues were found in Step 6**:

1. Present a categorized summary to the user:
   - Group findings by severity (Critical, Warning, Info)
   - For each finding, include: the check that found it, the file/line affected, and a brief assessment of what's wrong and likely cause

2. Use `AskUserQuestion` to ask the user how to proceed:
   - **Option 1: "Create a resolution plan"** — Enter plan mode. Create a plan
     with specific fixes for each issue, grouped by category. The user reviews
     the plan before any fixes are implemented.
   - **Option 2: "Continue to PR"** — Proceed to Step 8. Issues will be noted in the PR description and caught by CI.

### 8. Push and Create PR with Auto-Merge

Push the branch:

```bash
git push -u origin HEAD
```

Create PR with the `dependencies` label (to skip Claude review), or skip if an **open** PR already exists:

```bash
gh pr view --json state -q '.state' 2>/dev/null | grep -q OPEN || gh pr create --fill --label dependencies
```

Enable auto-merge (this will merge automatically when checks pass):

```bash
gh pr merge --auto --squash --delete-branch
```

### 9. Return to Main Worktree

Switch back to the main worktree while waiting for auto-merge:

```bash
cd ${GIT_HOME_PUBLIC}/nix-darwin/main
```

### 10. Report Summary

Tell the user:

1. What inputs were updated (from the nix flake update output)
2. The PR URL
3. Any warnings or errors found (from Step 6 output)
4. That auto-merge is enabled and will merge when checks pass
5. They can run `git pull` in the main worktree after the PR merges

**DO NOT wait for checks** - auto-merge handles this automatically.

**Note**: The worktree at `${GIT_HOME_PUBLIC}/nix-darwin/chore/flake-update-YYYY-MM-DD/` should be
removed manually after the PR is merged (`/wrap-up` or `/clean_gone`).
