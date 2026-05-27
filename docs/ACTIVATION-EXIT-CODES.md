# Darwin Rebuild Activation Exit Codes

## Overview

When running `sudo darwin-rebuild switch --flake .`, you may encounter various exit codes. This document explains what they mean and how to diagnose them.

## Exit Code 2

**Most Common Cause:** Non-critical home-manager activation failure via `launchctl asuser`

### Symptoms

```bash
$ sudo darwin-rebuild switch --flake .
[22:46:36] [INFO] Starting Home Manager activation
[22:46:37] [DEBUG] Completed writeBoundary phase
...
[22:46:57] [DEBUG] Claude settings validation exit code: 0
```

The rebuild appears to complete but returns exit code 2. Home-manager activation
succeeds (all phases complete), but the `launchctl asuser` wrapper returns a
non-zero exit code.

### Why This Happens

The nix-darwin activation script uses `set -e`, which means any command returning a non-zero exit code terminates the entire script. However:

1. **Home-manager activation succeeds** - All phases complete and files are written
2. **launchctl asuser returns 2** - The command that invoked home-manager returns non-zero
3. **Script is aborted** - Due to `set -e`, the entire darwin-rebuild exits with that code
4. **System IS updated** - Despite the exit code, `/run/current-system` symlink IS updated

### How to Verify Success

Check if the system was actually updated:

```bash
# Check if /run/current-system was updated
readlink /run/current-system
ls -l /run/current-system

# Compare with expected generation
nix flake show --allow-dirty | grep darwinConfigurations
```

If `/run/current-system` points to the correct system hash, **activation succeeded** despite the exit code 2.

### Why We Don't Suppress This Exit Code

We deliberately allow the exit code to propagate because:

1. **Transparency** - You should know something returned non-zero
2. **Diagnosis** - The exit code helps identify which phase had issues
3. **Safety** - Suppressing errors could hide real problems

Instead, we provide **comprehensive debug logging** (see Debug Output section below) so you can quickly diagnose what happened.

## Debug Output

The activation system now provides detailed timestamps and phase tracking:

```text
[HH:MM:SS] [INFO] Starting Home Manager activation
[HH:MM:SS] [DEBUG] Completed writeBoundary phase
[HH:MM:SS] [DEBUG] Completed linkGeneration phase
[HH:MM:SS] [DEBUG] Completed vscodeProfiles phase
[HH:MM:SS] [INFO] Home Manager activation completed
[HH:MM:SS] [DEBUG] Running Claude settings validation...
[HH:MM:SS] [DEBUG] Claude settings validation exit code: 0
[HH:MM:SS] [DEBUG] Configuring custom file extension mappings...
[HH:MM:SS] [INFO] Successfully registered 2 file extension(s)
[HH:MM:SS] [DEBUG] Launch Services database rebuilt
[HH:MM:SS] [DEBUG] Configuring Terminal.app profile...
[HH:MM:SS] [INFO] Terminal.app profile 'Basic' configured for 180x80
[HH:MM:SS] [INFO] Post-activation verification starting...
[HH:MM:SS] [INFO] ✓ System activation succeeded
[HH:MM:SS] [INFO] Current system: /nix/store/...darwin-system-26.05...
```

### Log Levels

- **[INFO]** - Major milestones and important events
- **[DEBUG]** - Detailed phase information and exit codes
- **[WARN]** - Non-critical issues (e.g., failed Launch Services rebuild)
- **[ERROR]** - Critical failures

## Recommended Workflow

When `darwin-rebuild switch` returns exit code 2:

1. **Check the symlink** - Verify `/run/current-system` was updated
2. **Review the output** - Look for `[ERROR]` or `[WARN]` messages
3. **Check specific phases** - Each activation phase reports its status
4. **Verify functionality** - Test your configuration to ensure it works

If the symlink is updated and there are no `[ERROR]` messages, the build succeeded.

## Other Exit Codes

| Code | Meaning | Action |
| --- | --- | --- |
| 0 | Success | Everything worked |
| 1 | Build failed | Check Nix evaluation errors |
| 2 | Activation phase returned non-zero | Check symlink and logs |
| 127 | Command not found | Check PATH and dependencies |

## Future Improvements

Tracking issues for comprehensive error handling:

1. **Set -e bypass** - Develop safe way to continue past non-critical failures
2. **Activation summary** - Report which phases succeeded/failed
3. **Error categorization** - Distinguish critical vs. non-critical failures
4. **Automatic rollback** - Consider reverting if critical phases fail
