# Plan: Add Python Packages and Modularization Strategy

> **Note**: Some file paths in this plan reference `modules/home-manager/` and
> `overlays/python-packages.nix` which have been moved to nix-ai and nix-home repos.
> This plan is historical.

## Part 1: Package Additions

### 1.1 Add jsondiff to Global Dev Package Set

**File**: `lib/python-environments.nix`

Add `jsondiff` to the existing `dev` package set (available to all Python 3.12+ environments):

```nix
dev =
  ps: with ps; [
    # Testing
    pytest
    pytest-asyncio
    pytest-cov
    coverage

    # Code quality
    ruff
    mypy
    black

    # Interactive
    ipython

    # Utilities (NEW)
    jsondiff        # JSON comparison and diffing
  ];
```

## Part 2: Python Implementation Review

### Current State (Good)

1. **Centralized definitions** in `lib/python-environments.nix`:
   - 5 Python versions (3.10-3.14)
   - 3 package sets (minimal, dev, data)
   - DRY `mkDevShell` helper function

2. **Overlays** in `overlays/python-packages.nix`:
   - Custom package versions when nixpkgs lags

3. **Per-version shells**: `python310/`, `python312/`, `python314/`

### Recommendations

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| No task-specific package sets | Add `ansible`, `web`, `automation` sets | Medium |
| Shells import lib inconsistently | Standardize all shells to use `lib/python-environments.nix` | Low |
| `splunk-dev` uses `uv` for Python 3.9 | Document as intentional (EOL workaround) | None |

## Part 3: Modularization Strategy

### Problem Statement

The repository has grown into a monolith with:

- **120 .nix files** in a single flake
- **14 nested shell flakes** that don't share inputs with root
- **42 files** in the Claude Code ecosystem alone
- **Per-host flakes** that redefine inputs independently

### Strategy: Graduated Sub-Flake Extraction

#### Phase 1: Extract Development Shells (Low Risk)

Create `shells/flake.nix` as a **sub-flake** that aggregates all shell environments:

```text
shells/
├── flake.nix              # NEW: aggregates all shells
├── python/flake.nix       # Consumes from parent
├── terraform/flake.nix
└── ...
```

**Benefits**:

- Single `nix develop github:owner/nix-darwin#shells.python312`
- Shared nixpkgs input across all shells
- Independent versioning possible

#### Phase 2: Extract AI-CLI Module (Medium Risk)

The `modules/home-manager/ai-cli/` subsystem (42 files) is a candidate for extraction:

```text
modules/home-manager/ai-cli/
├── flake.nix              # NEW: exports as home-manager module
├── claude/
├── gemini/
├── copilot/
└── common/
```

**Benefits**:

- Can be consumed by other flakes
- Independent testing and CI
- Clearer boundaries

#### Phase 3: Split Large Files

| File | Lines | Split Into |
|------|-------|------------|
| `claude/options.nix` | 356 | `types/marketplace.nix`, `types/mcp.nix`, `types/hook.nix` |
| `claude-config.nix` | 307 | `config/base.nix`, `config/plugins.nix`, `config/discovery.nix` |
| `user-config.nix` | 124 | `lib/user.nix`, `lib/system.nix` |

### Guidelines for New Components

1. **Size Threshold**: Files > 150 lines should be split
2. **Sub-Flake Criteria**:
   - Independently deployable
   - Has its own CI requirements
   - Consumed by multiple projects
3. **Naming**:
   - Skills: `noun-pattern.nix`
   - Modules: `noun.nix`
   - Shells: `shells/<purpose>/flake.nix`

## Implementation Order

1. **Add jsondiff** to `dev` package set in `lib/python-environments.nix` (global)
2. **Test** shells and run `nix flake check`

## Files to Modify

| File | Action |
|------|--------|
| `lib/python-environments.nix` | Add `jsondiff` to `dev` set |

## Verification

```bash
# Test jsondiff is globally available in Python 3.12 dev shell
nix develop ${GIT_HOME_PUBLIC}/nix-darwin/main/shells/python312 \
  --command python -c "import jsondiff; print('jsondiff OK')"

# Full flake check
nix flake check ${GIT_HOME_PUBLIC}/nix-darwin/main
```
