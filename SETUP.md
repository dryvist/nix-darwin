# Nix Darwin Setup - M4 Max MacBook Pro

## Table of Contents

- [Overview](#overview)
- [Setup Summary](#setup-summary)
- [Configuration Structure](#configuration-structure)
- [Issues Solved](#issues-solved)
- [What Was Migrated](#what-was-migrated)
- [Usage](#usage)
- [Key Decisions](#key-decisions)
- [Lessons Learned](#lessons-learned)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

---

## Overview

Minimal nix-darwin configuration with home-manager for macOS system management.

## Setup Summary

- **Date**: 2025-11-19
- **Machine**: MacBook Pro M4 Max (128GB RAM)
- **Nix Version**: 2.31.2 (Determinate Nix installer)
- **Darwin**: nix-darwin 25.05
- **Home Manager**: 25.05

## Configuration Structure

See [CLAUDE.md](CLAUDE.md) for complete directory structure with all files and descriptions.

## Issues Solved

### 1. Determinate Nix Compatibility

**Problem**: nix-darwin's Nix management conflicts with Determinate Nix installer.

**Solution**: Use the official `determinateNix` module in `modules/darwin/nix-storage.nix`:

```nix
determinateNix.enable = true;
```

**Why**: Determinate Nix manages its own daemon. The official module automatically sets `nix.enable = false`
and manages `/etc/nix/nix.custom.conf` declaratively — no manual override needed.

### 2. Documentation Build Warnings

**Problem**: Warning about `builtins.toFile` referencing store paths without proper context.

**Solution**: Disabled documentation building:

```nix
documentation.enable = false;
```

**Why**: The warning comes from upstream nix-darwin/home-manager documentation generation. Disabling documentation prevents the warning and speeds up builds.

### 3. Existing System Files Conflict

**Problem**: `/etc/bashrc` already existed and blocked activation.

**Solution**: Renamed existing file to `.before-nix-darwin` suffix:

```bash
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
```

**Why**: nix-darwin needs to manage system files. The backup allows reverting if needed.

### 4. Home Manager File Conflicts

**Problem**: Existing `~/.zshrc` prevented home-manager from managing it.

**Solution**: `home-manager.backupCommand = "rm -rf --"` is set in `lib/home-manager-defaults.nix`.

**Why**: Home-manager removes conflicting files/directories so it can place its managed symlinks.
The Nix store is the source of truth — pre-existing conflicting content is permanently deleted
(no `.backup` files). Rebuild to restore any HM-managed file.

### 5. Nix Settings Warnings

**Problem**: Warnings about unknown settings `eval-cores` and `lazy-trees`.

**Solution**: None required - warnings are harmless.

**Why**: Determinate Nix config uses forward-compatible settings for newer
Nix versions. Current version (2.31.2) simply ignores them. No functionality
is affected.

## What Was Migrated

### From ~/.zshrc to home-manager

All configuration moved to `home/home.nix`:

**Aliases**:

- `ll`, `llt`, `lls` - Enhanced ls with date formatting
- `python`, `pip` - Python 3.12 shortcuts
- `tgz` - Mac-friendly tar compression

**Functions**:

- `gitmd()` - Git merge and delete branch

**Environment**:

- Session logging to ~/logs/
- .DS_Store cleanup
- Tab width settings

## Usage

### Rebuild System

```bash
cd ~/.config/nix
nix flake check
sudo darwin-rebuild switch --flake ~/.config/nix
```

### Check Current Configuration

```bash
darwin-rebuild --version
home-manager --version
```

## Key Decisions

1. **Clean slate approach**: Started minimal instead of adapting Linux-based config
2. **Determinate Nix**: Using Determinate installer instead of official Nix
3. **Documentation disabled**: Cleaner builds, faster compilation
4. **File conflicts**: Conflicting files removed so home-manager can place symlinks
5. **Single profile initially**: Testing with default profile before adding complexity

## Lessons Learned

1. **Determinate Nix conflicts** with nix-darwin's Nix management — use
   `determinateNix.enable = true` (official module handles
   `nix.enable = false` automatically)
2. **Nix is the source of truth** - home-manager removes conflicting files to place symlinks;
   back up anything important before first rebuild
3. **Unknown setting warnings are harmless** - forward compatibility doesn't break functionality
4. **Flakes require git tracking** - all files must be `git add`ed before building
5. **Permissions matter** - some git objects created by Nix need ownership fixes

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Resources

See [README.md](README.md) for documentation links and references.
