# Permanent Fix

This document describes the multi-layered solution for nix-darwin boot activation failures.

## Understanding the Problem

Boot failures happen due to **three separate issues** (see [root-cause.md](root-cause.md)):

1. **Primary Issue**: nix-darwin's activation script requires a graphical session (Aqua) for App
   Management permission checks. At boot time, there's no GUI yet, so activation fails.

2. **Race Condition**: Scripts in `/nix/store` can't be executed before Determinate Nix mounts
   the volume. LaunchDaemons need to wait for `/nix/store` using `/bin/wait4path`.

3. **Tertiary Issue**: LaunchDaemons may not persist across reboots due to nix-darwin using
   deprecated `launchctl load` instead of `launchctl bootstrap`.

## Solution Architecture

```text
Boot Time (System Context)
    │
    ├──→ systems.determinate.nix-store (Determinate Nix)
    │    ✅ Mounts /nix volume
    │
    ├──→ org.nixos.symlink-boot (NEW - LaunchDaemon)
    │    ⏳ Waits for /nix/store via /bin/wait4path
    │    ✅ Creates /run/current-system symlink ONLY
    │    No permission checks, just the critical symlink
    │    Enables boot-time services (Ollama, OrbStack, etc.)
    │
    └──→ org.nixos.activate-system (original - LaunchDaemon)
         ❌ May fail: App Management requires GUI
         But symlink-boot already created the symlink!

Login Time (User Context)
    │
    └──→ org.nixos.activation-recovery (LaunchAgent)
         Runs full activation if anything is still broken
         Has GUI (Aqua) so all permission checks pass
```

## Implementation

### Part 1: Boot Activation (Critical - Creates Symlink at Boot)

This LaunchDaemon runs at boot and creates ONLY the `/run/current-system` symlink.
No permission checks, no App Management - just the critical symlink that boot-time
services need.

**File**: `modules/darwin/boot-activation.nix`

```nix
# Creates a LaunchDaemon that runs exactly once at boot
launchd.daemons.nix-boot-activation = {
  serviceConfig = {
    # Descriptive name - ONLY creates symlink, not full activation
    Label = "org.nixos.symlink-boot";

    # CRITICAL: Use wait4path to wait for /nix/store before executing
    # This prevents "No such file or directory" errors at early boot
    ProgramArguments = [
      "/bin/sh" "-c"
      "/bin/wait4path /nix/store && exec /bin/bash ${bootActivationScript}"
    ];

    RunAtLoad = true;
    LaunchOnlyOnce = true;  # Runs once, no retry (auto-recovery handles failures)
    UserName = "root";
  };
};
```

**What it does**:

1. Waits for `/nix/store` to be available (up to 60 seconds)
2. Reads `/nix/var/nix/profiles/system/systemConfig`
3. Creates `/run/current-system` symlink
4. Updates GC root
5. Logs to `/var/log/nix-boot-activation.log`

**Why this works**: This runs independently of nix-darwin's activate-system and has no
App Management permission checks. Boot-time services can start as soon as this completes.

### Part 2: Login Activation Recovery (Fallback)

This LaunchAgent runs after user login and runs full activation if needed.

**File**: nix-home `modules/home-manager/nix-activation-recovery.nix` (moved from this repo)

```nix
# See the actual file for full implementation
{
  options.programs.nix-activation-recovery = {
    enable = lib.mkEnableOption "automatic nix-darwin activation recovery after login";
  };

  config = lib.mkIf cfg.enable {
    launchd.agents.nix-activation-recovery = {
      enable = true;
      config = {
        Label = "org.nixos.activation-recovery";
        ProgramArguments = [ "${activationRecoveryScript}" ];
        RunAtLoad = true;
        KeepAlive = false;
        ThrottleInterval = 5;
      };
    };
  };
}
```

**Enable in your host configuration** (e.g., `hosts/macbook-m4/home.nix`):

```nix
{
  imports = [
    # ... other imports ...
    # nix-activation-recovery.nix is now provided by nix-home flake input
  ];

  programs.nix-activation-recovery.enable = true;
}
```

**Requires**: Passwordless sudo for activation (already configured in `modules/darwin/security.nix`):

```nix
environment.etc."sudoers.d/darwin-rebuild".text = ''
  ${username} ALL=(ALL) NOPASSWD: /nix/var/nix/profiles/system/activate
'';
```

### Part 3: LaunchDaemon Bootstrap (Ensures Persistence)

This ensures LaunchDaemons are properly registered during each activation.

**File**: `modules/darwin/launchd-bootstrap.nix`

```nix
# Workaround for nix-darwin#1255
# Ensures LaunchDaemons are bootstrapped using modern launchctl commands
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "[$(date '+%H:%M:%S')] [INFO] LaunchDaemon Bootstrap Check"

    for plist in /Library/LaunchDaemons/org.nixos.*.plist; do
      if [ -f "$plist" ]; then
        label=$(/usr/bin/plutil -extract Label raw "$plist" 2>/dev/null)
        if ! /bin/launchctl print system/"$label" >/dev/null 2>&1; then
          echo "[$(date '+%H:%M:%S')] [INFO] Bootstrapping $label..."
          /bin/launchctl bootstrap system "$plist" 2>/dev/null || true
        fi
      fi
    done
  '';
}
```

**Import in darwin configuration** (e.g., `hosts/macbook-m4/default.nix`):

```nix
{
  imports = [
    # ... other imports ...
    ../../modules/darwin/launchd-bootstrap.nix
  ];
}
```

### Part 4: Shell-Level Detection (User Feedback)

This provides immediate visual feedback when boot fails.

**File**: `modules/darwin/auto-recovery.nix`

Adds a check to zsh initialization that displays a prominent warning if `/run/current-system`
is missing, along with a `nix-recover` helper function.

## Rebuild

After making these changes:

```bash
cd ${GIT_HOME_PUBLIC}/nix-darwin/<worktree>
git add modules/
git commit -m "fix: multi-layered boot failure recovery"
sudo darwin-rebuild switch --flake .
```

## Verification Checklist

After implementing, verify:

- [ ] **LaunchAgent installed**: `launchctl list | grep activation-recovery`
- [ ] **LaunchDaemons loaded**: `launchctl list | grep org.nixos`
- [ ] **Sudo rule in place**: `sudo -l | grep activate`
- [ ] **Shell detection works**: Manually remove symlink and open new terminal
- [ ] **Test a reboot**: Full restart and confirm environment works

## How It Works Together

1. **At boot (early)**: Determinate Nix mounts `/nix` volume
2. **At boot (after mount)**: `org.nixos.symlink-boot` waits for `/nix/store`, then creates symlink
3. **At boot (parallel)**: `org.nixos.activate-system` runs but may fail (no GUI) - doesn't matter,
   symlink-boot already created the symlink
4. **Boot services start**: Ollama, OrbStack, etc. can now find their binaries
5. **At login (fallback)**: `org.nixos.activation-recovery` checks if full activation is needed
6. **If needed**: Runs `sudo /nix/var/nix/profiles/system/activate` with GUI context
7. **User notified**: macOS notification confirms recovery (if it ran)

## Logs

**Boot-time activation**:

- `/var/log/nix-boot-activation.log` - Boot activation log (persists across reboots)

**Login-time recovery**:

- `~/.local/log/nix-activation-recovery.log` - Recovery agent log
- `/tmp/nix-activation-recovery-stdout.log` - stdout
- `/tmp/nix-activation-recovery-stderr.log` - stderr

**Determinate Nix**:

- `/var/log/determinate-nix-init.log` - Volume mount and daemon startup

## Upstream Issues

- [nix-darwin#1255](https://github.com/nix-darwin/nix-darwin/issues/1255) - LaunchDaemon persistence
- App Management permission check requiring Aqua session (no upstream issue filed yet)
