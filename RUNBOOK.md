# Nix Configuration Runbook

Step-by-step procedures for common configuration tasks.

## Table of Contents

- [Everyday Commands](#everyday-commands)
- [Shell Aliases](#shell-aliases)
- [Adding Packages](#adding-packages)
- [Updating Packages](#updating-packages)
  - [Secure Flake Update Workflow](#secure-flake-update-workflow)
- [Rollback & Recovery](#rollback--recovery)
- [Dock Configuration](#dock-configuration)
- [Dev Shells](#dev-shells)
- [Host Profiles](#host-profiles)
- [CI and Caching](#ci-and-caching)

---

## Everyday Commands

```bash
# Rebuild after config changes (most common)
sudo darwin-rebuild switch --flake ~/.config/nix

# Search for a package
nix search nixpkgs <name>

# Rollback if something breaks
sudo darwin-rebuild --rollback

# List all generations
sudo darwin-rebuild --list-generations
```

---

## Shell Aliases

Configured shell aliases make common tasks faster. All aliases are defined
in nix-home (see [nix-home][nh-aliases]
`modules/home-manager/zsh/aliases.nix`).

[nh-aliases]: https://github.com/dryvist/nix-home

### Directory Listing

| Alias | Command | Purpose |
| --- | --- | --- |
| `ll` | `ls -ahlFG -D '%Y-%m-%d %H:%M:%S'` | Long listing with human-readable sizes |
| `ll@` | `ls -@ahlFG -D '%Y-%m-%d %H:%M:%S'` | Long listing with extended attributes (macOS) |
| `llt` | `ls -ahltFG -D '%Y-%m-%d %H:%M:%S'` | Long listing sorted by modification time |
| `lls` | `ls -ahlsFG -D '%Y-%m-%d %H:%M:%S'` | Long listing with file sizes |

**Extended Attributes**: The `ll@` alias displays macOS extended attributes (xattr), useful for viewing security contexts, quarantine flags, and other metadata:

```bash
# View extended attributes
ll@

# Example output:
# -rw-r--r--@ 1 user  staff  1024 2025-01-15 14:30:00 file.txt
#   com.apple.quarantine      57
#   com.apple.metadata:kMDItemWhereFroms      183
```

### Docker

| Alias | Command | Purpose |
| --- | --- | --- |
| `dps` | `docker ps -a` | List all containers |
| `dcu` | `docker compose up -d` | Start compose stack (detached) |
| `dcd` | `docker compose down` | Stop compose stack |

### Nix / Darwin

| Alias | Command | Purpose |
| --- | --- | --- |
| `d-r` | `sudo darwin-rebuild switch --flake .` | Rebuild system configuration |
| `nf-u` | `nix flake update --flake .` | Update flake.lock to latest versions |

### AWS

| Alias | Command | Purpose |
| --- | --- | --- |
| `av` | `aws-vault exec` | Execute command with AWS profile |
| `avl` | `aws-vault list` | List profiles in vault |
| `avd` | `aws-vault exec default --` | Execute with default profile |
| `ava` | `aws-vault add` | Add profile to vault |
| `avr` | `aws-vault remove` | Remove profile from vault |

### Other

| Alias | Command | Purpose |
| --- | --- | --- |
| `python` | `python3` | Use Python 3 by default |
| `tgz` | `tar --disable-copyfile --exclude='.DS_Store' -czf` | Create tar.gz (macOS-friendly) |

---

## Adding Packages

### Adding a Nix Package (Preferred)

1. **Search nixpkgs first**:

   ```bash
   nix search nixpkgs <package>
   ```

2. **Add to system packages** in `modules/darwin/common.nix`:

   ```nix
   environment.systemPackages = with pkgs; [
     existing-package
     new-package  # Description of what it does
   ];
   ```

3. **Commit and rebuild**:

   ```bash
   cd ~/.config/nix
   git add .
   git commit -m "feat: add <package>"
   sudo darwin-rebuild switch --flake .
   ```

### Adding a Homebrew Package (Fallback Only)

Only use Homebrew when:

- Package doesn't exist in nixpkgs
- Nixpkgs version is severely outdated
- Package requires Homebrew-specific integration

1. **Add to homebrew casks** in `modules/darwin/common.nix`:

   ```nix
   homebrew.casks = [
     "package-name"  # Why: not in nixpkgs
   ];
   ```

2. **Document the reason** in a comment

3. **Commit and rebuild**

### Adding a Mac App Store App

1. **Find the app ID**:

   ```bash
   mas search "<app name>"
   ```

2. **Add to mas apps** in `modules/darwin/common.nix`:

   ```nix
   homebrew.masApps = {
     "App Name" = 123456789;
   };
   ```

3. **Commit and rebuild**

---

## Updating Packages

### Update All Nix Packages

Nix flakes pin exact versions. To get newer versions:

```bash
cd ~/.config/nix

# 1. Update flake.lock to latest nixpkgs
nix flake update

# 2. Commit the updated lock file (required for flakes)
git add flake.lock
git commit -m "chore: update flake inputs"

# 3. Rebuild with new versions
sudo darwin-rebuild switch --flake .
```

**Recommended frequency**: Weekly or when you notice outdated packages.

### Update Homebrew Packages

**Important**: Homebrew has NO native background auto-update mechanism. The "passive auto-update"
is just a convenience feature that runs `brew update` if >5 minutes have passed when you invoke
certain brew commands. There is no background daemon.

**How homebrew packages stay current:**

| Method | Trigger | What Happens |
| --- | --- | --- |
| darwin-rebuild | `sudo darwin-rebuild switch --flake .` | Upgrades all packages (primary method) |
| Manual update | `brew update && brew upgrade` | Immediate update when needed |
| Passive auto-update | Running `brew install/upgrade/etc` | Index updated if >5 minutes stale |

**Our configuration** in `modules/darwin/homebrew.nix`:

- `autoUpdate = false` → Keeps rebuilds fast (no 45MB index download on every rebuild)
- `upgrade = true` → Packages upgraded to latest when darwin-rebuild runs
- Passive auto-update is enabled (Homebrew's default behavior)

**Standard workflow** (recommended):

```bash
# Rebuild updates homebrew packages automatically
sudo darwin-rebuild switch --flake ~/.config/nix
```

**Emergency/immediate update** (when you need latest versions now):

```bash
# 1. Update Homebrew's package index
brew update

# 2. Upgrade all packages immediately
brew upgrade

# 3. Sync nix configuration (records the update)
sudo darwin-rebuild switch --flake ~/.config/nix
```

**Why Renovate doesn't track homebrew packages:**

Renovate cannot automatically update homebrew packages because:

1. nix-darwin's `homebrew.brews/casks` contain only package names, not versions
2. Homebrew lacks declarative version pinning within configuration files
3. Renovate's homebrew manager only works with Ruby Formula files

The `darwin-rebuild switch` workflow is the correct approach for keeping homebrew packages current.

### If Something Breaks After Update

```bash
cd ~/.config/nix

# Undo the flake.lock update
git revert HEAD

# Rebuild with old versions
sudo darwin-rebuild switch --flake .
```

### Secure Flake Update Workflow

For production or critical systems, follow this secure workflow before applying updates:

#### 1. Build (Dry-Run)

Preview what would change without actually building:

```bash
cd ~/.config/nix
nix flake update  # Update flake.lock
nix build .#darwinConfigurations.$(hostname).system --dry-run
```

This shows package changes and download sizes without committing storage.

#### 2. Diff Package Changes

Compare current system with the updated configuration. Choose your preferred diff tool:

##### Option A: Native Nix (always available)

```bash
# Build the new configuration first
nix build .#darwinConfigurations.$(hostname).system -o result

# Compare closures
nix store diff-closures /run/current-system ./result
```

##### Option B: nvd (if installed)

```bash
nvd diff /run/current-system ./result
```

Both tools show version changes, additions, and removals for every package.

#### 3. Audit Critical Packages

**Human review required** - do not automate this step.

Review changes to security-sensitive packages:

- System packages (nix, darwin-rebuild)
- Security tools (gpg, ssh, certificates)
- Development tools with network access
- Packages with privileged access

**Check versions and lifecycles:**

- Review package version changes from step 2
- Check [endoflife.date](https://endoflife.date/) for NixOS and critical packages
- Verify packages are within supported lifecycle dates
- Look for major version jumps that may require configuration changes

**Security advisory check:**

- Search for CVEs affecting packages with significant version changes
- Review GitHub Security Advisories for key packages
- Check nixpkgs issue tracker for known problems

#### 4. Switch with Confidence

Only proceed after completing human review:

```bash
# Commit the flake.lock update
git add flake.lock
git commit -m "chore: update flake inputs"

# Apply the update
sudo darwin-rebuild switch --flake .
```

#### 5. Rollback Procedures

If issues occur after switching:

**Immediate rollback:**

```bash
# Rollback to previous generation
sudo darwin-rebuild --rollback
```

**Revert flake.lock:**

```bash
cd ~/.config/nix
git revert HEAD
sudo darwin-rebuild switch --flake .
```

**Switch to specific generation:**

```bash
# List available generations
sudo darwin-rebuild --list-generations

# Activate specific generation
sudo /nix/var/nix/profiles/system-<N>-link/activate
```

**Note**: This workflow adds safety checks before updates. For development systems or low-risk updates,
the standard "update and rebuild" workflow in [Updating Packages](#updating-packages) is sufficient.

### Handling Renovate PRs

**Renovate Bot** automatically creates PRs for dependency updates. This section covers how to review and merge them.

#### Renovate Update Schedule

Renovate creates PRs on a schedule based on package criticality:

| Package Group | Schedule | Auto-merge |
| --- | --- | --- |
| Critical Infrastructure (nixpkgs, darwin, home-manager) | Mon/Thu 3am | No |
| AI Tools (claude-code-plugins, etc.) | Sun/Wed/Fri 10pm | Yes (patch/minor) |
| npm Packages (cclint, chatgpt-cli, gh-copilot) | Monday 10pm | Yes (patch/minor) |

**Auto-merge policy:**

- **Patch** (1.2.3 → 1.2.4) and **Minor** (1.2.3 → 1.3.0): Auto-merge after CI passes
- **Major** (1.2.3 → 2.0.0): Manual review required

#### Check for Renovate PRs

```bash
# List all Renovate PRs
gh pr list --search "author:app/renovate"

# View Dependency Dashboard (shows pending updates)
gh issue list --search "Dependency Dashboard in:title"
```

#### Review a Renovate PR

1. **Check the PR details**:

   ```bash
   gh pr view <pr-number>
   ```

   Review:
   - Package names and version changes
   - Release notes and changelog links
   - Whether it's a patch, minor, or major update

2. **Check CI status**:

   ```bash
   gh pr checks <pr-number>
   ```

   Wait for all checks to pass:
   - `nix flake check` (syntax validation)
   - Package staleness check
   - AI review (risk assessment)

3. **Review AI risk assessment**:

   - Look for comment from `claude-code` bot
   - Check risk level: LOW, MEDIUM, or HIGH
   - LOW risk: Safe to auto-merge
   - MEDIUM/HIGH risk: Review changes carefully

4. **Test locally (optional for major updates)**:

   ```bash
   # Checkout the Renovate PR branch
   gh pr checkout <pr-number>

   # Build without switching
   sudo darwin-rebuild build --flake .

   # If build succeeds, test switch
   sudo darwin-rebuild switch --flake .

   # Verify everything works, then merge the PR
   ```

#### Merge a Renovate PR

**Auto-merge (patch/minor updates):**

Renovate will auto-merge after CI passes. No action needed.

**Manual merge (major updates or high risk):**

```bash
# Option 1: Merge via gh CLI
gh pr review <pr-number> --approve
gh pr merge <pr-number> --squash

# Option 2: Merge via GitHub UI
# Go to PR page, click "Squash and merge"
```

**After merge:**

```bash
# Pull the merged changes
cd ~/.config/nix
git checkout main
git pull

# Rebuild with updated packages
sudo darwin-rebuild switch --flake .
```

#### Handling Failed Renovate Updates

**If CI checks fail:**

1. View the failure:

   ```bash
   gh pr checks <pr-number> --watch
   ```

2. Common failures:
   - **Package staleness**: Renovate tried to update one package but others are still stale
     - Resolution: Wait for Renovate to update all packages, or manually update: `nix flake update`
   - **Build failure**: Package has breaking changes
     - Resolution: Check PR comments for migration guide, fix configuration
   - **Conflict**: PR is out of date with main
     - Resolution: Renovate will auto-rebase, or close/reopen PR

3. If update is problematic:

   ```bash
   # Close the PR (Renovate will retry later)
   gh pr close <pr-number>

   # Or pin the package version in renovate.json5
   # (see "Pinning Package Versions" below)
   ```

#### Pinning Package Versions

If a package update causes issues, temporarily pin the version:

1. **Edit** `.github/renovate.json5`:

   ```json5
   {
     "packageRules": [
       {
         "matchPackageNames": ["problematic-package"],
         "enabled": false,  // Disable updates entirely
         // OR
         "allowedVersions": "<2.0.0"  // Pin below major version
       }
     ]
   }
   ```

2. **Document the pin** with a comment and GitHub issue:

   ```json5
   // PINNED: 2026-01-02 - v2.0.0 has breaking changes
   // TODO: Unpin when migration is complete (see #123)
   ```

3. **Commit and push**:

   ```bash
   git add .github/renovate.json5
   git commit -m "chore(deps): pin <package> due to breaking changes"
   git push
   ```

4. **Create issue** to track unpinning work:

   ```bash
   gh issue create --title "Unpin <package> after migration" \
     --body "Temporarily pinned in renovate.json5 due to breaking changes"
   ```

#### Dependency Dashboard

Renovate maintains a **Dependency Dashboard** issue that shows:

- Pending updates (waiting for schedule)
- Rate-limited updates (max 3 concurrent PRs)
- Conflicted PRs (need rebase)
- Manually approved updates

**View the dashboard:**

```bash
gh issue list --search "Dependency Dashboard in:title"
```

**Manually trigger an update:**

1. Go to Dependency Dashboard issue
2. Check the box next to the package you want to update
3. Renovate will create a PR within minutes

#### Troubleshooting Renovate

**Renovate not creating PRs:**

1. Check if Renovate App is installed:

   ```bash
   gh api --paginate repos/:owner/:repo/collaborators | jq '.[] | select(.login == "renovate[bot]")'
   ```

2. Check Dependency Dashboard for errors or rate limits

3. Validate configuration:

   ```bash
   npx --yes renovate-config-validator
   ```

**Renovate PRs auto-closing:**

1. Check CI logs for failures
2. Verify `automerge` settings in `.github/renovate.json5`
3. Check for branch protection rules

**Too many Renovate PRs:**

Renovate has a 3 concurrent PR limit. Merge some PRs to allow new ones.

**Custom workflow conflicts with Renovate:**

The custom workflow (`.github/workflows/deps-update-flake.yml`) automatically skips
if a Renovate PR exists. No manual intervention needed.

---

## Rollback & Recovery

### Quick Rollback

```bash
# Rollback to previous generation
sudo darwin-rebuild --rollback
```

### Switch to Specific Generation

```bash
# List available generations
sudo darwin-rebuild --list-generations

# Activate specific generation
sudo /nix/var/nix/profiles/system-<N>-link/activate
```

### Emergency Recovery

If the system is broken and normal commands fail:

```bash
# Boot into recovery mode or use another terminal
# Activate a known-good generation directly
sudo /nix/var/nix/profiles/system-1-link/activate
```

## Dock Configuration

### Change Dock App Order

1. **Edit** `modules/darwin/dock/persistent-apps.nix`

2. **Reorder apps** in the `persistent-apps` list (order = left to right)

3. **Commit and rebuild**

### Add an App to the Dock

1. **Find the app path**:

   ```bash
   # System apps
   ls /System/Applications/

   # Nix-managed apps
   ls "/Applications/Nix Apps/"

   # Manual installs
   ls /Applications/

   # User apps
   ls ~/Applications/
   ```

2. **Add to** `modules/darwin/dock/persistent-apps.nix`:

   ```nix
   persistent-apps = [
     # ... existing apps ...
     "/Applications/NewApp.app"
   ];
   ```

3. **Commit and rebuild**

### Add Items to Right Side of Dock (After Separator)

Use `persistent-others` for folders, stacks, or utility apps:

```nix
persistent-others = [
  "${homeDir}/Downloads"  # homeDir from user-config.nix
  "/System/Applications/System Settings.app"
];
```

### Dock Settings Reference

All dock behavior settings are in `modules/darwin/dock/default.nix`:

- Icon size, magnification
- Autohide behavior
- Hot corners
- Mission Control settings

---

## Dev Shells

### Using a Dev Shell

```bash
# Enter a development environment
nix develop ~/.config/nix#python
nix develop ~/.config/nix#python-data
nix develop ~/.config/nix#js
nix develop ~/.config/nix#go
nix develop ~/.config/nix#terraform
```

### Creating a New Dev Shell

1. **Create shell directory**: `shells/<name>/`

2. **Create flake.nix**:

   ```nix
   {
     description = "Shell description";

     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
       flake-utils.url = "github:numtide/flake-utils";
     };

     outputs = { self, nixpkgs, flake-utils }:
       flake-utils.lib.eachDefaultSystem (system:
         let pkgs = nixpkgs.legacyPackages.${system};
         in {
           devShells.default = pkgs.mkShell {
             packages = with pkgs; [
               # Add packages here
             ];
           };
         }
       );
   }
   ```

3. **Add to main flake.nix** in the `devShells` section

### Modifying an Existing Dev Shell

1. **Edit** `shells/<name>/flake.nix`

2. **Test the shell**:

   ```bash
   nix develop ~/.config/nix#<name>
   ```

No rebuild required - dev shells are evaluated on-demand.

---

## Host Profiles

### Switch to a Different Host Profile

```bash
# Uses hostname to auto-detect configuration
sudo darwin-rebuild switch --flake ~/.config/nix
```

### Creating a New Host Profile

1. **Create host directory**: `hosts/<hostname>/`

2. **Create default.nix** (system config):

   ```nix
   { ... }:
   {
     imports = [
       ../../modules/darwin/common.nix
     ];

     # Host-specific overrides here
   }
   ```

3. **Create home.nix** (user config):

   ```nix
   { ... }:
   {
     # User-level config is provided by nix-ai and nix-home flake inputs.
     # Host-specific user settings (e.g., Ollama, APFS volumes) go here.
   }
   ```

4. **Add to flake.nix** in `darwinConfigurations`

### Modifying Host-Specific Settings

- **System settings**: `hosts/<hostname>/default.nix`
- **User settings**: `hosts/<hostname>/home.nix`
- **Shared darwin settings**: `modules/darwin/common.nix`
- **User dev tools**: nix-home (see [nix-home](https://github.com/JacobPEvans/nix-home))
- **AI tools**: nix-ai (see [nix-ai](https://github.com/JacobPEvans/nix-ai))

---

## AI CLI Permissions

AI CLI permissions (Claude, Gemini, Copilot) are now managed in nix-ai.
See [nix-ai](https://github.com/JacobPEvans/nix-ai) for permission configuration.

### Quick Permission Approval

For one-off approvals without editing Nix:

- Click "Accept indefinitely" in Claude UI
- Saves to `~/.claude/settings.local.json` (not Nix-managed)

---

## CI and Caching

CI uses `nix-community/cache-nix-action@v7` — Nix-aware, free, restore-only on PRs, saves on
main. For full context (rationale, rejected alternatives, performance expectations), see
`.claude/rules/ci-workflows.md`.

Workflow files:

- `.github/workflows/_nix-build.yml` — macOS Nix build and home-manager check
- `.github/workflows/_claude-settings.yml` — Claude settings validation

### Check Cache Status

Look for the "Cache Nix Store" step in any CI run. It reports cache hit/miss and key:

```bash
gh run list --repo JacobPEvans/nix-darwin --limit 5
gh run view <run-id> --log --repo JacobPEvans/nix-darwin | grep -A5 "Cache Nix Store"
```

### When CI Is Slow

**Cold cache (expected):** First run after `flake.lock` changes falls back to prefix-matching —
slower than a full hit. Normal; the next main push saves a warm cache.

**Actual regression:** Builds consistently above 10min without a cache key change. Investigate:

1. New dependency bloating the Nix store
2. "Build Timing" notices in CI logs across recent runs
3. `gc-max-store-size-macos` (5G) being hit frequently
