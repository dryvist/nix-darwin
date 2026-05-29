---
description: Add a package to the Nix configuration with proper workflow
model: sonnet
allowed-tools: Read, Edit, Write, Grep, Glob, Bash(nix search *), Bash(brew *), Bash(git *), Bash(darwin-rebuild *), Bash(sudo darwin-rebuild *), Bash(home-manager *), Bash(gh *), Bash(ssh-add *)
---

# Quick Add Package

Add a package to the Nix configuration using the proper development workflow.

**Input**: `$ARGUMENTS` = package name (e.g., "claude-monitor")

> [!NOTE]
> All commands should be run from the repository root unless otherwise specified.

## Workflow Steps

### 1. Git Refresh (Sync Repository)

```bash
/git-refresh
```

This ensures your local repo is up-to-date before making changes.

### 2. Search nixpkgs (then Homebrew if needed)

```bash
nix search nixpkgs <pkg-name>
```

Verify the package exists and note its attribute name.

**If NOT found in nixpkgs**, check Homebrew as fallback:

```bash
brew search <pkg-name>
brew info <pkg-name>
```

Per project rules: nixpkgs first, Homebrew only when package is unavailable in nixpkgs.

### 3. Create Worktree

Create a dedicated worktree for the change (NEVER work on main).

**From the bare repo root** (`${GIT_HOME_PUBLIC}/nix-darwin`):

```bash
cd ${GIT_HOME_PUBLIC}/nix-darwin
git fetch origin
git worktree add feat/add-<pkg-name> -b feat/add-<pkg-name> origin/main
cd feat/add-<pkg-name>
```

The worktree is created at `${GIT_HOME_PUBLIC}/nix-darwin/feat/add-<pkg-name>/`.

### 4. Determine Installation Location

**For nixpkgs packages**, search the codebase to find where similar packages are installed:

- **macOS-specific tools**: `modules/darwin/common.nix` in `environment.systemPackages`
- **User dev tools**: nix-home (`home.packages`) — not in this repo
- **AI tools**: nix-ai — not in this repo
- **Claude-specific tools**: Next to `claude-code` in `modules/darwin/common.nix` (Development tools section)

**For Homebrew packages** (when not in nixpkgs):

- **CLI tools**: `modules/darwin/common.nix` in `homebrew.brews` list
- **GUI apps**: `modules/darwin/common.nix` in `homebrew.casks` list
- Always add a comment explaining why Homebrew is needed (e.g., "not in nixpkgs")

> [!IMPORTANT]
> Keep all package lists (nixpkgs and Homebrew) sorted alphabetically for maintainability.
>
### 5. Make Changes

**Read** the target file to understand existing sections, then **Add** the package with a brief comment.

### 6. Commit Changes

```bash
git add <modified-file>
git commit -m "feat(packages): add <pkg-name>"
```

Pre-commit hooks will run automatically. If they fail, fix issues and re-commit.

### 7. Validate Configuration

```bash
nix flake check
```

Ensure the flake is valid.

### 8. Check SSH Agent

```bash
ssh-add -l
```

Verify SSH agent is ready before pushing.

### 9. Push and Create PR

```bash
git push -u origin feat/add-<pkg-name>
gh pr create --title "feat(packages): add <pkg-name>" --body "Adds the <pkg-name> package to the Nix configuration."
```

### 10. Wait for Approval

- **DO NOT** rebuild or merge without explicit user approval
- CI will run automatically when the PR is created
- Address any review feedback by committing additional fixes

### 11. After Merge (User Will Handle)

Once the user approves and merges the PR, they will rebuild:

```bash
sudo darwin-rebuild switch --flake .  # macOS
# or
home-manager switch --flake .  # Linux
```

### 12. Cleanup (After Merge)

Once the PR is merged, clean up your local environment:

```bash
# Navigate to the bare repo root
cd ${GIT_HOME_PUBLIC}/nix-darwin

# Remove the worktree
git worktree remove feat/add-<pkg-name>

# Delete the local feature branch
git branch -d feat/add-<pkg-name>
```

**Note**: After the PR merges, run `/wrap-up` or `/clean_gone` to remove the worktree and the now-merged local branch.

---

## Key Principles

✅ **Always use `/git-refresh` first** - Ensures local repo is synced
✅ **Always create a worktree** - Never work on main directly
✅ **Always commit before pushing** - Allows pre-commit hooks to run
✅ **Always create a PR** - Maintains audit trail and CI validation
✅ **Always wait for approval** - User must explicitly approve before merging

❌ **Never skip git-refresh** - Can cause merge conflicts
❌ **Never work on main** - Feature branches are mandatory
❌ **Never bypass pre-commit hooks** - They catch issues early
❌ **Never auto-merge** - Requires explicit user approval
❌ **Never rebuild before approval** - User decides when to apply changes
