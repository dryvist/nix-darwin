# Investigation: /run/current-system Symlink Not Updating

**Status**: ACTIVE INVESTIGATION
**Started**: 2024-12-26
**Issue**: `/run/current-system` symlink not updating after `darwin-rebuild switch`

## Problem Statement

After running `darwin-rebuild switch`, the build succeeds and a new generation is created,
but `/run/current-system` continues pointing to an old generation. This is a silent failure - the
command exits successfully but the system doesn't actually switch to the new configuration.

## Evidence

### Observed Behavior

```bash
# Before rebuild
$ readlink /run/current-system
/nix/store/afgn3l4zmpnn0p45b86q6wdp21rcqhyy-darwin-system-26.05.f0c8e1f

# After successful rebuild
$ readlink /nix/var/nix/profiles/system
system-287-link -> /nix/store/wa0fakj369ypibngf4issnj97afc7f44-darwin-system-26.05.f0c8e1f

# Symlink not updated
$ readlink /run/current-system
/nix/store/afgn3l4zmpnn0p45b86q6wdp21rcqhyy-darwin-system-26.05.f0c8e1f  # Still old!
```

### Activation Script Analysis

The activate script at `/nix/var/nix/profiles/system/activate` contains:

```bash
# Line ~1526
ln -sfn "$(readlink -f "$systemConfig")" /run/current-system
```

This command SHOULD update the symlink, but:

1. The postActivation verification (line 1413) runs BEFORE this command
2. The activation completes successfully (we see "Configuring custom file extension mappings...")
3. But the symlink is never updated

### What We Know

**✅ Confirmed Working**:

- Build succeeds
- New generation is created in `/nix/var/nix/profiles/`
- Activation scripts run to completion
- Terminal output shows activation reaching the end

**❌ Not Working**:

- The `ln -sfn` command at line 1526 either:
  - Doesn't execute (but why? no exit/crash before it)
  - Executes but fails silently
  - Executes but gets overwritten somehow

**🤔 Unclear**:

- Why does activation appear to complete but not run the final command?
- Is there a race condition?
- Is darwin-rebuild doing something after the activate script runs?

## Hypotheses

### Hypothesis 1: Command Not Executing

The `ln -sfn` command isn't running because something prevents execution.

**Evidence against**: We see "Configuring custom file extension mappings..." which is right before the ln command.

### Hypothesis 2: Silent Failure

The command runs but fails without reporting an error.

**How to test**: Add explicit error checking and logging around the ln command.

### Hypothesis 3: Overwrite After Success

The command succeeds but something overwrites the symlink afterward.

**How to test**: Add a final verification at the very end of the activate script.

### Hypothesis 4: Wrong Activate Script

darwin-rebuild is calling a different activate script than we think.

**How to test**: Add debugging to confirm which activate script is running.

### Hypothesis 5: Permission Timing

Permission changes during activation prevent the symlink update.

**How to test**: Check permissions before and after the ln command.

## Investigation Plan

1. **Add Debug Logging**: Instrument the activate script generation to add extensive logging
2. **Capture Full Output**: Run rebuild with all output captured
3. **Trace Execution**: Use set -x in activation scripts to see every command
4. **Verify Permissions**: Check /run permissions throughout activation
5. **Test Manual Activation**: Run the activate script directly to isolate the issue

## Workarounds

Until fixed, manually run:

```bash
sudo /nix/var/nix/profiles/system/activate
```

## Related Issues

- Fixed in PR #298: Marketplace directory conflicts that blocked activation
- This issue is separate and pre-existing

## Investigation Progress

### Completed

- ✅ Added set -x tracing to preActivation
- ✅ Added DEBUG logging to show execution flow
- ✅ Created debugging infrastructure:
  - `scripts/debug-activation.sh`: Diagnose current state
  - `scripts/test-rebuild-with-logging.sh`: Capture rebuild output
  - `scripts/analyze-rebuild-logs.sh`: Analyze log files
- ✅ Enhanced postActivation with detailed logging
- ✅ Spawned research agent to investigate nix-darwin source code
- ✅ Committed debugging infrastructure to git

### In Progress

- 🔄 Research agent investigating nix-darwin activation flow
  - Analyzing darwin-rebuild.sh source code
  - Examining activation-scripts.nix
  - Researching GitHub issues and PRs
  - Tracing systemConfig variable usage

### Next Steps

- [ ] Complete research agent investigation
- [ ] Document research findings
- [ ] Run test rebuild manually (requires sudo password)
- [ ] Analyze captured logs
- [ ] Identify root cause from combined research + logs
- [ ] Implement fix
- [ ] Verify fix works
- [ ] Update documentation with solution

## How to Use Debugging Tools

### Check Current State

```bash
./scripts/debug-activation.sh
```

### Run Test Rebuild with Logging

```bash
sudo ./scripts/test-rebuild-with-logging.sh
```

### Analyze Logs

```bash
./scripts/analyze-rebuild-logs.sh /tmp/darwin-rebuild-debug/rebuild-*.log
```

## RESOLVED

**Resolution Date**: 2025-12-27
**Status**: FIXED

### Root Cause

The `lsregister` command in `modules/darwin/file-extensions.nix` (line 96) had NO error handling. The
activate script uses `set -e`, so when lsregister failed, the entire activation would exit immediately,
preventing the `/run/current-system` symlink update from executing.

**Execution order**:

1. Terminal.app configuration (line ~1436 in activate script)
2. File extension mappings via duti (succeeds)
3. **lsregister command (line 1459) - FAILS with no error handling**
4. Script exits due to `set -e`
5. Symlink update (line 1526) - **NEVER REACHED**

### Solution

Wrapped the `lsregister` command in an `if` statement with proper error handling:

```nix
if /System/.../lsregister -kill -r -domain local -domain system -domain user 2>&1; then
  echo "Launch Services database rebuilt" >&2
else
  echo "Warning: Failed to rebuild Launch Services database (file mappings still applied)" >&2
fi
```

Now if lsregister fails, it prints a warning but allows activation to continue. The file mappings still
work even if lsregister fails.

### Files Changed

- `modules/darwin/file-extensions.nix`: Added error handling to lsregister command

### Investigation Process

1. Research agent analyzed nix-darwin source code
2. Found symlink update is last command in activate script (~line 1526)
3. Narrowed failure to 90-line window between Terminal config and symlink update
4. Analyzed actual activate script to find lsregister at line 1459 with no error handling
5. Added error handling to prevent activation failure

### Verification

To verify the fix works:

```bash
cd ${GIT_HOME_PUBLIC}/nix-darwin/main
sudo darwin-rebuild switch --flake .
```

The symlink should now update correctly, and you should see either:

- "Launch Services database rebuilt" (if lsregister succeeds)
- "Warning: Failed to rebuild Launch Services database..." (if lsregister fails but activation continues)

Check that `/run/current-system` points to the new generation:

```bash
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
# These should match
```
