# Troubleshooting Guide

Common issues and solutions for this nix-darwin configuration.

## Table of Contents

- [Sudo Requirements](#sudo-requirements)
- [Quick Fixes](#quick-fixes)
- [Boot Failures](#boot-failures)
- [Why Packages "Disappear"](#why-packages-disappear)
- [Package Management Issues](#package-management-issues)
- [Application Issues](#application-issues)
- [File Recovery](#file-recovery)
- [Related Documentation](#related-documentation)

---

## Sudo Requirements

Understanding when `sudo` is needed prevents permission issues.

### Commands That REQUIRE sudo

| Command | Why |
| --- | --- |
| `darwin-rebuild switch` | Modifies system-level configs in /etc, /run |
| `chown` on system files | Changing ownership requires root |
| `mv/rm` in /etc | System config directory |

**Correct usage**: See [RUNBOOK.md](RUNBOOK.md#everyday-commands) for the rebuild command.

### Commands That Should NOT Use sudo

| Command | Why |
| --- | --- |
| `nix build` | Builds to user-accessible store |
| `nix flake update` | Updates user's flake.lock |
| `git commit/push` | User's repository |
| Editing files in `~/.config/nix` | User's config directory |
| `brew install/uninstall` | Homebrew runs as user |

**Warning**: Running these as sudo creates root-owned files that break later operations.

### Fixing Root-Owned Files in User Directories

**Problem**: Files in `~/.config/nix` owned by root (usually from running editor as sudo).

**Solution**:

```bash
# Fix ownership of entire nix config directory
sudo chown -R $(whoami):staff ~/.config/nix

# Verify
ls -la ~/.config/nix
```

### AI CLI Tools and sudo

**Claude Code, Gemini CLI, etc.**:

- Should run as your user, NOT as sudo
- Running as sudo causes:
  - GPG signing failures (root can't access user's keychain)
  - Root-owned files in user directories
  - Home directory set to /var/root

**If you ran `sudo claude`**:

```bash
# Fix any root-owned files it created
sudo chown -R $(whoami):staff ~/.config/nix ~/.claude ~/.gitconfig
```

---

## Quick Fixes

### "command not found: nix"

Source the Nix daemon script:

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Git permission errors during build

Fix ownership of .git directory:

```bash
sudo chown -R $(whoami):staff ~/.config/nix/.git
```

### Activation fails with "files in the way"

Rename conflicting files with `.before-nix-darwin` suffix:

```bash
sudo mv /etc/conflicting-file /etc/conflicting-file.before-nix-darwin
```

### Home-manager activation fails

`backupCommand = "rm -rf --"` is set in `lib/home-manager-defaults.nix` to handle
conflicting files. If activation still fails, remove the conflicting path manually:

```bash
rm -rf ~/.path/to/conflicting/file-or-dir
darwin-rebuild switch --flake .
```

### "error: attribute 'package-name' missing"

Package name differs in nixpkgs. Search for it:

```bash
nix search nixpkgs <partial-name>
```

### Changes not applying

1. Commit your changes to git (flakes require this)
2. Rebuild (see [RUNBOOK.md](RUNBOOK.md#everyday-commands))
3. Open a new terminal

---

## Boot Failures

### System Broken After Restart (Empty PATH, Commands Not Found)

**Problem**: After restarting your Mac, the Nix environment is completely broken:

- `echo $PATH` shows nothing or only `/usr/bin:/bin`
- `darwin-rebuild: command not found`
- `/run/current-system` doesn't exist
- Shell completions and oh-my-zsh not working

**Root Cause**: nix-darwin's LaunchDaemons (`org.nixos.activate-system`) weren't loaded at boot,
so the activation script never ran.

**Quick Fix**:

```bash
# Bootstrap the missing services
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.darwin-store.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.activate-system.plist

# Run activation
sudo /nix/var/nix/profiles/system/activate

# Start new shell
exec zsh
```

**Permanent Fix**: The `modules/darwin/launchd-bootstrap.nix` module ensures services are
bootstrapped during every activation.

**Full Documentation**: See [docs/boot-failure/](docs/boot-failure/) for:

- **[Quick Recovery](docs/boot-failure/README.md)** - Step-by-step recovery commands
- **[Root Cause](docs/boot-failure/root-cause.md)** - Why this happens
- **[Permanent Fix](docs/boot-failure/permanent-fix.md)** - Prevention implementation
- **[Diagnostics](docs/boot-failure/diagnostics.md)** - Advanced diagnostic commands

---

## Why Packages "Disappear"

Packages installed outside of nix (manual `brew install`, `npm -g`, etc.) are NOT tracked by nix-darwin.
After system updates or profile switches, these packages may vanish because:

1. They weren't in the nix store
2. PATH changes to prioritize nix-managed paths (`/run/current-system/sw/bin`)
3. Homebrew state isn't preserved by nix

**Solution**: Always add packages to `modules/darwin/common.nix` and rebuild.

---

## Package Management Issues

### Duplicate Packages (Homebrew vs Nix)

**Problem**: `which <package>` shows `/opt/homebrew/bin` instead of `/run/current-system/sw/bin`.

**Solution**:

1. **Verify the duplicate**:

   ```bash
   which claude  # Shows /opt/homebrew/bin/claude (wrong)
   ls -la /run/current-system/sw/bin/claude  # Verify nix version exists
   ```

2. **Check for homebrew installations**:

   ```bash
   brew list --formula  # List all formulas
   brew list --cask     # List all casks
   ```

3. **Backup important configurations** (GPG keys, app settings):

   ```bash
   cp -R ~/.config/app ~/backup/app-$(date +%Y-%m-%d)/
   ```

4. **Remove homebrew versions as user** (not root):

   ```bash
   # For command-line tools
   sudo -u <username> brew uninstall <package>
   # For GUI applications
   sudo -u <username> brew uninstall --cask <package>
   ```

5. **Verify nix version is now found**:

   ```bash
   which <package>  # Should show /run/current-system/sw/bin/<package>
   ```

### PATH Priority (Homebrew Before Nix)

**Problem**: `/opt/homebrew/bin` appears before `/run/current-system/sw/bin` in PATH.

**Correct PATH Order**:

```text
/Users/<username>/.nix-profile/bin
/etc/profiles/per-user/<username>/bin
/run/current-system/sw/bin          ← Nix packages here
/nix/var/nix/profiles/default/bin
/opt/homebrew/bin                   ← Homebrew fallback only
```

**Solution**:

1. Check `~/.zprofile` for homebrew shellenv initialization
2. Remove or comment out manual homebrew PATH additions
3. Let nix-darwin manage PATH via `/etc/zshenv`
4. Open new terminal to get updated PATH

### Activation Failure (Binaries Show Old Versions) - RESOLVED

**Problem**: `darwin-rebuild switch` completes successfully but running binaries show old versions.

**Example**: `claude --version` shows 2.0.74 when expected version is 2.0.76.

**Root Cause**: The `lsregister` command in `modules/darwin/file-extensions.nix` had NO error
handling. The activate script uses `set -e`, so when lsregister failed, the entire activation would
exit immediately, preventing the `/run/current-system` symlink update from executing.

**Status (as of 2025-12-27)**: ✅ **FULLY RESOLVED**

- ✅ **Fixed**: Marketplace directory conflicts that blocked activation
- ✅ **Fixed**: lsregister command now has proper error handling
- ✅ **Verified**: Investigation confirmed root cause and solution

**How It Was Fixed**:

The `lsregister` command (used to rebuild macOS Launch Services database) is now wrapped in proper
error handling:

```nix
if /System/.../lsregister -kill -r -domain local -domain system -domain user 2>&1; then
  echo "Launch Services database rebuilt" >&2
else
  echo "Warning: Failed to rebuild Launch Services database (file mappings still applied)" >&2
fi
```

If lsregister fails, activation now continues with a warning instead of exiting.

**Investigation Timeline**:

1. Research agent analyzed nix-darwin source code
2. Found symlink update is last command in activate script (~line 1526)
3. Narrowed failure to 90-line window between Terminal config and symlink update
4. Analyzed actual activate script to find lsregister at line 1459 with no error handling
5. Added error handling to prevent activation failure

**Verification**:

After rebuilding, you should see either:

- "Launch Services database rebuilt" (if lsregister succeeds)
- "Warning: Failed to rebuild Launch Services database..." (if lsregister fails but activation
  continues)

Check that `/run/current-system` now updates correctly:

```bash
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
# These should match
```

**Historical Workaround** (no longer needed):

```bash
# Old workaround when activation failed:
sudo /nix/var/nix/profiles/system/activate
```

---

### Claude Code Marketplace Symlink Conflicts (FIXED)

**Problem**: `darwin-rebuild switch` would crash with:

```text
cmp: /nix/store/.../superpowers-marketplace: Is a directory
ln: ~/.claude/plugins/marketplaces/superpowers-marketplace: cannot overwrite directory
```

**Root Cause**: Runtime plugin installs (via `/plugin install`) create real directories at
`~/.claude/plugins/marketplaces/*`, but Nix tries to create symlinks at the same paths. This
creates a conflict that blocks home-manager's `linkGeneration` phase.

**Solution**: Fixed in nix-ai `modules/home-manager/ai-cli/claude/plugins.nix` (PR #298):

1. **Pre-checkLinkTargets Cleanup**: `cleanupConflictingDirectorySymlinks` runs BEFORE
   `checkLinkTargets` to remove real directories and stale symlinks at marketplace paths
2. **backupCommand**: `rm -rf --` removes any remaining conflicts so HM can place symlinks

**Verification**: After rebuild, confirm all marketplace entries are symlinks:

```bash
ls -la ~/.claude/plugins/marketplaces/
# All entries should show lrwxr-xr-x (symlinks), none drwxr-xr-x (real dirs)
```

**Status**: ✅ RESOLVED - Activation now completes successfully past this point

---

## Application Issues

### mac-app-util Build Failure (gitlab.common-lisp.net)

**Problem**: Build fails with errors like:

```text
tar: This does not look like a tar archive
do not know how to unpack source archive
```

**Cause**: `gitlab.common-lisp.net` has deployed Anubis anti-bot protection, which blocks Nix's automated source fetches for the `iterate` Common Lisp library.

**Solution**: The flake.nix already includes a workaround using a fork with GitHub mirrors:

```nix
mac-app-util = {
  url = "github:hraban/mac-app-util";
  inputs.cl-nix-lite.url = "github:r4v3n6101/cl-nix-lite/url-fix";
};
```

**Reference**: [mac-app-util issue #39](https://github.com/hraban/mac-app-util/issues/39)

### macOS TCC Permissions Reset After Rebuild

**Problem**: Camera, microphone, screen recording, or App Management permissions revoked after `darwin-rebuild switch`.

**Cause**: macOS TCC (Transparency, Consent, Control) tracks permissions by full file path.
Every Nix rebuild changes the `/nix/store/...` path, causing macOS to treat apps as "new"
and revoke permissions.

**Solution Architecture**:

This configuration uses multiple layers to ensure TCC permissions persist:

1. **mac-app-util trampolines**: Apps in `home.packages` get stable wrapper
   apps at `~/Applications/Home Manager Trampolines/` that don't change paths
   across rebuilds

2. **TCC-sensitive apps in home.packages**: Ghostty, Zoom, and OrbStack are in
   `home.packages` (see `hosts/macbook-m4/home.nix`) (not system packages) to get
   stable trampolines

3. **/bin/zsh fallback**: The system shell has a permanent path and can be granted Full Disk Access as a backup

### Setting Up TCC Permissions (One-Time)

After a fresh install or if permissions aren't working:

1. **Grant Full Disk Access to Ghostty trampoline**:
   - Open System Settings > Privacy & Security > Full Disk Access
   - Click the `+` button
   - Navigate to `~/Applications/Home Manager Trampolines/Ghostty.app`
   - Enable the toggle

2. **Grant Full Disk Access to /bin/zsh** (fallback):
   - In Full Disk Access, click `+`
   - Press `Cmd+Shift+G` and enter `/bin/zsh`
   - Enable the toggle

3. **Verify trampolines exist**:

```bash
# Check Home Manager trampolines
ls -la "~/Applications/Home Manager Trampolines/"
# Should show Ghostty.app, Zoom.app, OrbStack.app

# Check system apps (these do NOT get stable TCC)
ls -la /Applications/Nix\ Apps/
# Apps here change paths on rebuild - don't grant TCC to these
```

### Why This Works

- **Trampoline paths are stable**: `~/Applications/Home Manager Trampolines/Ghostty.app` never changes, even when the underlying Nix store path does
- **TCC stores permissions by path**: Once Ghostty trampoline has Full Disk Access, it persists across rebuilds
- **/bin/zsh is immutable**: Apple's system shell path never changes, providing a reliable fallback

### Troubleshooting TCC Issues

**darwin-rebuild fails with permission errors**:

```bash
# Verify you're running from Ghostty (not Terminal.app)
echo $TERM_PROGRAM
# Should show: Ghostty

# If using Terminal.app, grant it Full Disk Access or switch to Ghostty
```

**Permissions revoked after macOS update**:

macOS updates can sometimes reset TCC. Re-grant permissions to:

- `~/Applications/Home Manager Trampolines/Ghostty.app`
- `/bin/zsh`

### GPG "unsafe ownership" Warning

**Problem**: `gpg: WARNING: unsafe ownership on homedir '/Users/<username>/.gnupg'`

**Solution**:

```bash
# Fix ownership (replace <username> with your macOS username)
sudo chown -R <username>:staff ~/.gnupg

# Fix directory permissions (700)
sudo -u <username> find ~/.gnupg -type d -exec chmod 700 {} \;

# Fix file permissions (600)
sudo -u <username> find ~/.gnupg -type f -exec chmod 600 {} \;

# Verify
gpg --list-keys
```

### Invalid BWS Access Token

**Problem**: BWS-backed automation fails with:

```text
Error: Access token is not in a valid format: Doesn't contain a decryption key
```

**Cause**: The BWS (Bitwarden Secrets Manager) access token stored in macOS Keychain is corrupted or invalid.

**Impact**:

- Headless Claude authentication fails (LaunchAgent automation)
- `claude-api-key-helper` script fails

**Solution**:

> **Note**: These instructions use the default keychain service name `bws-claude-automation`.
> If you've customized this via `programs.claude.apiKeyHelper.keychainService` in your Nix
> configuration, replace `bws-claude-automation` with your configured value throughout these steps.

1. **Delete the corrupted token**:

   ```bash
   security delete-generic-password -s "bws-claude-automation"
   ```

2. **Get a new Machine Account token**:
   - Go to [Bitwarden Secrets Manager](https://vault.bitwarden.com)
   - Navigate to your Machine Accounts
   - Create or regenerate an access token

3. **Add the new token to keychain**:

   ```bash
   security add-generic-password -s "bws-claude-automation" -a "$USER" -w "NEW_TOKEN_HERE"
   ```

4. **Verify the token works**:

   ```bash
   export BWS_ACCESS_TOKEN=$(security find-generic-password -s "bws-claude-automation" -w)
   bws secret list
   ```

   Expected: List of secrets (not an error)

**Prevention**: BWS tokens can become invalid if:

- They are revoked in Bitwarden Secrets Manager
- The Machine Account is deleted or regenerated
- Token expiration (if configured)

---

## File Recovery

### Configuration File Became Empty

**Problem**: A `.nix` configuration file was truncated to 0 bytes.

**Solution**:

1. **Restore from git**:

   ```bash
   cd ~/.config/nix
   git restore <path-to-file>
   ```

**Prevention**: Always commit changes before rebuilding.

---

## Related Documentation

- [README.md](README.md) - Quick reference and commands
- [SETUP.md](SETUP.md) - Initial setup and configuration decisions
- [RUNBOOK.md](RUNBOOK.md) - Common commands and procedures
- [docs/boot-failure/README.md](docs/boot-failure/README.md) - Boot failure recovery guide
- [docs/ACTIVATION-SCRIPTS-RULES.md](docs/ACTIVATION-SCRIPTS-RULES.md) - Rules for writing activation scripts
- [docs/ACTIVATION-EXIT-CODES.md](docs/ACTIVATION-EXIT-CODES.md) - Understanding activation exit codes
