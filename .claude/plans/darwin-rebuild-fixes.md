# Darwin-Rebuild Issues Resolution Plan

> **Note**: Some file paths in this plan reference `modules/home-manager/` which
> has been moved to nix-ai and nix-home repos. This plan is historical.

## Summary

Fix all warnings and errors from `darwin-rebuild switch --flake .` output, standardize log formatting, and add regression prevention.

## Issues to Fix

| Issue | Severity | File(s) |
|-------|----------|---------|
| SlashCommand schema validation error | CRITICAL | `permissions.nix` |
| WakaTime config not overwriting | MEDIUM | `claude/default.nix` |
| Timestamp format inconsistency | LOW | 3 files |
| Launch Services rebuild warning | LOW | `file-extensions.nix` |
| Syslog connectivity validation | ENHANCEMENT | `logging.nix` |

## Implementation Order

### Phase 1: Critical Fix (SlashCommand)

**File**: `modules/home-manager/ai-cli/common/permissions.nix:139`

**Problem**: "SlashCommand" is not a valid Claude Code tool per schema.

**Valid tools**: Bash, Edit, ExitPlanMode, Glob, Grep, KillShell, NotebookEdit, Read, Skill, Task, TodoWrite, WebFetch, WebSearch, Write, mcp__*

**Fix**: Remove "SlashCommand" from builtin list:

```nix
# Line 130-140: BEFORE
builtin = [
  "Read"
  "Edit"
  "Write"
  "NotebookEdit"
  "Glob"
  "Grep"
  "WebSearch"
  "TodoWrite"
  "SlashCommand"  # REMOVE THIS LINE
];
```

**Verification**:

```bash
nix flake check
darwin-rebuild switch --flake .
# Should see NO schema validation errors
```

### Phase 2: Timestamp Format Standardization

**Target format**: `YYYY-MM-DD HH:MM:SS [LEVEL] message` (no brackets around timestamp)

**Files to update**:

1. **`modules/darwin/logging.nix`** (11 occurrences)
   - Lines: 36, 67, 68, 69, 70, 75, 77, 82, 84, 87, 88
   - Change: `[$(date '+%Y-%m-%d %H:%M:%S')]` to `$(date '+%Y-%m-%d %H:%M:%S')`

2. **`modules/darwin/boot-activation.nix`** (1 occurrence)
   - Line 19: Update log function format

3. **`modules/home-manager/nix-activation-recovery.nix`** (1 occurrence)
   - Line 40: Update log function format

**Verification**:

```bash
darwin-rebuild switch --flake .
# All log lines should match: "2026-02-04 10:30:45 [INFO] message"
```

### Phase 3: WakaTime Config Management

**Current**: Creates file only if not exists (lines 73-88 in `claude/default.nix`)

**Problem**: User wants Nix to fully manage, but file contains API key

**Solution**: Environment variable substitution approach

```nix
wakatimeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  WAKATIME_CFG="${config.home.homeDirectory}/.wakatime.cfg"
  API_KEY="''${WAKATIME_API_KEY:-waka_YOUR-API-KEY-HERE}"

  $DRY_RUN_CMD cat > "$WAKATIME_CFG" <<EOF
[settings]
api_key = $API_KEY
EOF
  $DRY_RUN_CMD chmod 600 "$WAKATIME_CFG"

  if [ "$API_KEY" = "waka_YOUR-API-KEY-HERE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Created $WAKATIME_CFG with placeholder"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Set WAKATIME_API_KEY env var or edit manually"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Created $WAKATIME_CFG from environment"
  fi
'';
```

**Usage**: Set `WAKATIME_API_KEY` in shell profile or pass to darwin-rebuild

### Phase 4: Launch Services Error Handling

**File**: `modules/darwin/file-extensions.nix:69-84`

**Improvement**: Add retry logic and better error messaging

```bash
ls_attempts=0
ls_success=false
while [ $ls_attempts -lt 2 ] && [ "$ls_success" != "true" ]; do
  ls_attempts=$((ls_attempts + 1))
  if /System/Library/Frameworks/.../lsregister -kill -r -domain local -domain system -domain user 2>"$LS_ERROR_LOG" >/dev/null; then
    ls_success=true
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Launch Services database rebuilt"
  elif [ $ls_attempts -lt 2 ]; then
    sleep 1
  fi
done

if [ "$ls_success" != "true" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Launch Services rebuild failed - extensions registered but may need re-login" >&2
fi
```

### Phase 5: Syslog Connectivity Test (Optional)

**File**: `modules/darwin/logging.nix`

**Status**: UDP connectivity confirmed working via `nc -zu` test

**Enhancement**: Add DNS resolution check and test message to activation script

```bash
SYSLOG_HOST="<your-syslog-host>"
SYSLOG_PORT="1514"

if host "$SYSLOG_HOST" >/dev/null 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Syslog DNS: OK"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Cannot resolve: $SYSLOG_HOST" >&2
fi

/usr/bin/logger -p local0.info "nix-darwin syslog test"
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Syslog test message sent"
```

## Regression Prevention

### Add Tool Validation Assertion

**File**: `permissions.nix` (new assertion)

```nix
validClaudeTools = [
  "Bash" "Edit" "ExitPlanMode" "Glob" "Grep" "KillShell"
  "NotebookEdit" "Read" "Skill" "Task" "TodoWrite"
  "WebFetch" "WebSearch" "Write"
];

# Add assertion to fail build if invalid tool added
```

### Update CI Workflow

**File**: `.github/workflows/_claude-settings.yml`

Ensure schema validation runs and fails the build on errors (currently just warns).

### Timestamp Format Linting

Add grep check to pre-commit or CI:

```bash
# Fail if bracketed timestamp format found
! grep -rn '\[.*\$(date' modules/
```

## Test Plan

1. **Pre-implementation**:

   ```bash
   cd ${GIT_HOME_PUBLIC}/nix-darwin/main
   git status  # Confirm clean state
   nix flake check  # Baseline
   ```

2. **After each phase**:

   ```bash
   nix flake check
   darwin-rebuild switch --flake . 2>&1 | tee /tmp/rebuild.log
   grep -i "error\|warn" /tmp/rebuild.log
   ```

3. **Final validation**:

   ```bash
   # No schema errors
   cat ~/.claude/settings.json | jq '.permissions.allow' | grep -i slash
   # Should return nothing

   # Timestamps consistent
   grep -E '^\[?[0-9]{4}-' /tmp/rebuild.log
   # All lines should match: "YYYY-MM-DD HH:MM:SS [LEVEL]"

   # WakaTime managed
   cat ~/.wakatime.cfg
   # Should exist and be writable by Nix

   # Syslog working
   logger -p local0.info "test" && echo "Syslog OK"
   ```

## Files Modified

| File | Changes |
|------|---------|
| `modules/home-manager/ai-cli/common/permissions.nix` | Remove SlashCommand, add validation |
| `modules/darwin/logging.nix` | Fix timestamp format, add connectivity test |
| `modules/darwin/boot-activation.nix` | Fix timestamp format |
| `modules/home-manager/nix-activation-recovery.nix` | Fix timestamp format |
| `modules/darwin/file-extensions.nix` | Improve lsregister error handling |
| `modules/home-manager/ai-cli/claude/default.nix` | WakaTime env var approach |
