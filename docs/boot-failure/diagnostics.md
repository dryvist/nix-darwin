# Diagnostic Commands

Advanced diagnostic commands for investigating boot failures and system state.

## Quick Health Check

```bash
# One-liner to check if boot succeeded
ls -la /run/current-system && echo "✅ Boot succeeded" || echo "❌ Boot failed"
```

## Log Files to Check

| Log File | What It Shows |
| --- | --- |
| `/var/log/nix-boot-activation.log` | Boot-time symlink creation (our fix) |
| `/var/log/determinate-nix-init.log` | Volume mount and Nix daemon startup |
| `~/.local/log/nix-activation-recovery.log` | Login-time recovery attempts |
| `/tmp/nix-activation-recovery-*.log` | Recovery stdout/stderr |

```bash
# Check boot activation log (most important)
tail -20 /var/log/nix-boot-activation.log

# Check if boot-activation ran for current boot
sysctl kern.boottime  # Get boot time
cat /var/log/nix-boot-activation.log | grep "$(date '+%Y-%m-%d')"

# Check Determinate Nix log
tail -20 /var/log/determinate-nix-init.log

# Check recovery log
cat ~/.local/log/nix-activation-recovery.log 2>/dev/null | tail -10
```

## Check What's Broken

```bash
# Check if /run/current-system exists
ls -la /run/current-system 2>&1
# "No such file or directory" = activation didn't run

# Check if services are loaded
launchctl list | grep -E "(nix|darwin)"
# Should show org.nixos.activate-system with exit code

# Check if boot-activation service ran (label: org.nixos.symlink-boot)
launchctl print system/org.nixos.symlink-boot 2>&1 | head -10
# "Could not find service" = LaunchOnlyOnce completed, check log instead

# Check activate-system exit code
launchctl print system/org.nixos.activate-system 2>&1 | grep "last exit code"
# "last exit code = 1" = App Management permission failed

# Check if plists exist
ls -la /Library/LaunchDaemons/org.nixos.*.plist
# Should show activate-system.plist, symlink-boot.plist, darwin-store.plist

# Check if plists are valid
plutil -lint /Library/LaunchDaemons/org.nixos.activate-system.plist
# Should say "OK"

# Check service status in detail
sudo launchctl print system/org.nixos.activate-system
# "Could not find service" = not loaded
# Detailed output = loaded but may have failed
```

## Check What's Working

```bash
# Determinate Nix daemon (should be running)
launchctl list | grep determinate
# Should show systems.determinate.nix-daemon with PID

# Nix store is mounted
mount | grep nix
# Should show /dev/disk... on /nix

# System profile exists
ls -la /nix/var/nix/profiles/system
# Should show symlink to system-XXX-link
```

## Check Boot Logs

```bash
# Look for activation attempts at boot
log show --last boot --predicate 'eventMessage CONTAINS "activate"' | head -20

# Check launchd errors
log show --last boot --predicate 'subsystem == "com.apple.launchd"' | grep -i nix
```

## Additional Diagnostics

### Check PATH Configuration

```bash
# Show PATH in order
echo "$PATH" | tr ':' '\n' | nl

# Check if Nix paths come first
echo "$PATH" | grep -o '^[^:]*'
# Should show a Nix path, not /usr/bin
```

### Check Shell Configuration

```bash
# Check which shell config files are sourced
echo "ZDOTDIR: $ZDOTDIR"
ls -la ~/.zshrc ~/.zshenv ~/.zprofile 2>&1

# Check for /etc/zshrc (nix-darwin managed)
ls -la /etc/zshrc /etc/static/zshrc 2>&1
```

### Check Nix Daemon

```bash
# Check Nix daemon status
launchctl list systems.determinate.nix-daemon

# Test Nix daemon connection
nix-store --version
nix eval --expr '1 + 1'
```

### Check System Generation

```bash
# Show current system generation
ls -la /nix/var/nix/profiles/system

# Show last 5 generations
ls -la /nix/var/nix/profiles/ | grep system- | tail -5

# Show what changed in last activation
nix-store --query --references /nix/var/nix/profiles/system | head -10
```
