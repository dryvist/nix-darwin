# Root Cause Explanation

## Why Boot Failures Happen

There are **multiple issues** that can cause boot failures with Determinate Nix + nix-darwin:

### Issue 1: App Management Permission Check (Primary Cause)

**This is the main reason activation fails at boot.**

**Symptom**: TWO macOS notifications appear at login:
> "bash" was prevented from modifying apps on your Mac

These TWO notifications come from TWO different scripts that both try to modify `/Applications/Nix Apps/`:

1. **nix-darwin activation** (line ~301 in activate script):

   ```bash
   echo "setting up /Applications/Nix Apps..." >&2
   ```

2. **darwin-level (system) trampolines** (line ~1481 in activate script):

   ```bash
   mac-app-util sync-trampolines "/Applications/Nix Apps" "/Applications/Nix Trampolines"
   ```

   **Note**: This repository removed `mac-app-util` from home-manager (switched to `copyApps`
   for user-level apps). Only system-level packages still use trampolines.

The activation script includes an App Management permission check that **requires a graphical
session (Aqua)** to succeed:

```bash
# From activate script (line 167)
if [[ "$(launchctl managername)" != Aqua ]]; then
    # Fails with exit code 1 - "permission denied"
fi
```

**At boot time:**

1. `org.nixos.activate-system` LaunchDaemon runs
2. No graphical session exists yet - `launchctl managername` != "Aqua"
3. The App Management check fails → activation exits with code 1
4. `/run/current-system` symlink is never created
5. User sees TWO "bash prevented" notifications at login (queued from boot)

**Diagnostic command:**

```bash
launchctl print system/org.nixos.activate-system | grep "last exit code"
# If this shows "last exit code = 1", the script ran but failed
```

### Issue 2: Race Condition with /nix/store Mount

**Issue identified**: 2025-12-31 during boot testing

LaunchDaemons that reference Nix store paths can fail if they start before `/nix` is mounted:

```text
/bin/bash: /nix/store/xxx-script: No such file or directory
```

**The Problem:**

1. launchd starts all `RunAtLoad` services early in boot
2. Some services reference scripts in `/nix/store` (e.g., `ProgramArguments = ["/bin/bash", "/nix/store/..."]`)
3. If Determinate Nix hasn't mounted `/nix` yet, bash can't find the script
4. Service fails immediately with "No such file or directory"

**The Fix:**

Use `/bin/wait4path /nix/store &&` before executing scripts in the Nix store:

```xml
<key>ProgramArguments</key>
<array>
  <string>/bin/sh</string>
  <string>-c</string>
  <string>/bin/wait4path /nix/store &amp;&amp; exec /bin/bash /nix/store/xxx-script</string>
</array>
```

**Diagnostic:**

Check `/var/log/nix-boot-activation.log` for timestamps. If there are no log entries for
the current boot, the script likely failed before even starting (race condition).

### Issue 3: LaunchDaemon Bootstrap (Tertiary Cause)

**Upstream Issue**: [nix-darwin#1255](https://github.com/nix-darwin/nix-darwin/issues/1255)

On modern macOS (Ventura+), LaunchDaemons need explicit bootstrap via `launchctl bootstrap`.
nix-darwin uses deprecated `launchctl load` which doesn't persist reliably.

This is a **tertiary issue** - even if the LaunchDaemon IS loaded, Issues 1 and 2 may cause it to fail.

## Service Architecture

| Service Owner | Services | Boot Behavior |
| --- | --- | --- |
| **Determinate Nix** | `systems.determinate.nix-store` | ✅ Works - mounts `/nix` volume |
| **Determinate Nix** | `systems.determinate.nix-daemon` | ✅ Works - socket activation |
| **nix-darwin** | `org.nixos.darwin-store` | ⚠️ May need bootstrap |
| **nix-darwin** | `org.nixos.activate-system` | ❌ Runs but FAILS (exit code 1) |

The `org.nixos.activate-system` service is responsible for:

1. Creating `/run/current-system` symlink
2. Running activation scripts
3. Setting up `/etc/static/*` symlinks
4. Configuring shell environment variables

## The Chain of Failure

```text
Boot
  └─→ /nix volume mounted (Determinate Nix - works)
  └─→ org.nixos.activate-system runs (nix-darwin)
        └─→ App Management check: "launchctl managername" != "Aqua"
              └─→ Script exits with code 1 (no GUI session at boot)
                    └─→ /run/current-system symlink NOT created
                          └─→ Shell config can't find NIX_PROFILES
                                └─→ PATH is empty
                                      └─→ All Nix commands "not found"
```

## Why Manual Recovery Works

When you run `sudo /nix/var/nix/profiles/system/activate` from a terminal:

1. You're in a graphical session - `launchctl managername` returns "Aqua"
2. The App Management check passes
3. Activation completes successfully
4. `/run/current-system` is created

This is why the environment "fixes itself" after manual activation but breaks again on reboot.

## Why Determinate Nix Works But nix-darwin Fails

Determinate Nix services:

- Use socket activation (no permission checks needed)
- Are bootstrapped during installation
- Don't require GUI access

nix-darwin's activation:

- Requires App Management permission for `/Applications/Nix Apps/`
- This permission check requires a graphical session
- At boot time, no graphical session exists yet

## Issue 4: Trampoline App Permissions (User Experience)

**Observed**: 2025-12-31 during manual activation

Even after fixing the boot issues, trampoline apps (like Ghostty) have permission problems:

**The Problem:**

1. The dock shows trampoline apps with generic script icons
2. Launching a trampoline spawns a NEW dock icon with the correct icon
3. The new icon points to the actual Nix store path: `/nix/store/xxx-ghostty-bin-1.2.3/Applications/`
4. macOS prompts for App Management permission for the **Nix store path**, not the trampoline
5. On next rebuild, the Nix store path changes, and permission must be granted AGAIN

**Why This Happens:**

macOS TCC (Transparency, Consent, Control) grants permissions to **specific binary paths**.
Nix store paths are content-addressed and change whenever the package is rebuilt.

```text
Before rebuild: /nix/store/abc123-ghostty-1.2.3/...  ← Permission granted
After rebuild:  /nix/store/def456-ghostty-1.2.4/...  ← NEW path, needs permission again
```

**Current Workarounds:**

1. Grant permission each time (tedious but works)
2. Add the Nix Apps directory to Full Disk Access (security implications)
3. Use `tccutil` to grant permissions programmatically (complex)

**Status After `copyApps` Migration (Home-Manager Apps):**

This repository now uses Home Manager's `copyApps` feature instead of trampolines for
user-managed applications (see `hosts/macbook-m4/home.nix`). `copyApps` creates real `.app`
bundles at stable paths under `~/Applications`, so macOS TCC grants App Management permission
to a fixed location rather than a changing Nix store path.

**Result**: The repeated permission prompts and associated boot-time activation failures
described above are **resolved for home-manager–managed apps** in this configuration.
System-level packages still use trampolines and may experience this issue.

Related upstream issues:

- [nix-darwin#1255](https://github.com/nix-darwin/nix-darwin/issues/1255) - LaunchDaemon bootstrap
- [home-manager#5189](https://github.com/nix-community/home-manager/issues/5189) - Trampoline apps (partially addressed by copyApps)
