# Nix Boot Failure Recovery

Quick recovery guide for nix-darwin boot failures where the system appears broken after restart.

## Symptoms

After a system restart, you may experience:

| Symptom | What You'll See |
| --- | --- |
| Empty PATH | `echo $PATH` shows nothing or only `/usr/bin:/bin` |
| Commands not found | `darwin-rebuild: command not found` |
| Missing symlink | `ls /run/current-system` returns "No such file or directory" |
| Nix commands fail | `nix` works but `darwin-rebuild` doesn't |
| Shell looks broken | zsh completions missing, oh-my-zsh not loading |

**Quick Check**: Run this to confirm the issue:

```bash
ls -la /run/current-system
# If this returns "No such file or directory", your activation didn't run at boot
```

---

## Quick Recovery

### Step 1: Bootstrap Missing LaunchDaemons

The root cause is that nix-darwin's launchd services weren't loaded at boot. Load them manually:

```bash
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.darwin-store.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.activate-system.plist
```

**Expected output**: No output means success. If you see an error like "service already loaded",
that's also fine.

**Verify they're loaded**:

```bash
launchctl print system/org.nixos.activate-system
# Should show service details, NOT "Could not find service"
```

### Step 2: Run Activation

```bash
sudo /nix/var/nix/profiles/system/activate
```

**Expected output**: You'll see activation messages like:

```text
setting up /etc...
setting up launchd services...
```

**If activation fails**, see [Common Activation Errors](#common-activation-errors) below.

### Step 3: Start Fresh Shell

```bash
exec zsh
```

### Step 4: Verify Recovery

```bash
# Check PATH is populated
echo $PATH | tr ':' '\n' | head -5
# Should show /run/current-system/sw/bin and other Nix paths

# Check darwin-rebuild works
which darwin-rebuild
# Should show /run/current-system/sw/bin/darwin-rebuild

# Check system symlink exists
ls -la /run/current-system
# Should show symlink to /nix/store/...

# Check launchd services
launchctl list | grep org.nixos
# Should show org.nixos.activate-system and org.nixos.darwin-store
```

---

## Common Activation Errors

### Error: "Unexpected files in /etc"

```text
error: Unexpected files in /etc, aborting activation
The following files have unrecognized content and would be overwritten:
  /etc/zshrc
  /etc/bashrc
```

**Fix**: Rename conflicting files:

```bash
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
# Then retry activation
sudo /nix/var/nix/profiles/system/activate
```

### Error: "Homebrew installation required"

```text
error: Using the homebrew module requires homebrew installed
```

**Fix**: Install Homebrew first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Then retry activation
sudo /nix/var/nix/profiles/system/activate
```

### Error: Permission denied

```text
error: permission denied when trying to update apps
```

**Fix**: Grant terminal Full Disk Access:

1. Open System Settings > Privacy & Security > Full Disk Access
2. Add your terminal app (Ghostty, Terminal.app, etc.)
3. Retry activation

---

## Related Documentation

- **[Root Cause Explanation](root-cause.md)** - Why this happens
- **[Permanent Fix](permanent-fix.md)** - Prevent future occurrences
- **[Diagnostics](diagnostics.md)** - Advanced diagnostic commands
- **[TROUBLESHOOTING.md](../TROUBLESHOOTING.md)** - General troubleshooting guide
- **[Incident Log](incident-log.md)** - Historical boot failure incidents
