# Flake Update Strategy

Renovate's Nix preset owns `flake.lock` maintenance. It opens a consolidated
lock-file update PR on the preset's weekend cadence; the repository's normal
CI and merge rules apply. Do not add a second workflow that writes the lock
file.

When changing an input declaration in `flake.nix`, include the corresponding
`nix flake lock` update. The `nixpkgs` input tracks the selected channel branch;
Renovate lock-file maintenance refreshes the locked revision as that branch
advances.

## Claude Code updates

Claude Code follows the same Renovate lock-maintenance path as the other flake
inputs. Validate the flake, then review the update PR and test the application
during `darwin-rebuild`. Accept the update unless testing finds a concrete
regression.

## Validation gates

Before accepting Claude Code updates:

```bash
# Validate flake structure
nix flake check

# Rebuild darwin system
sudo darwin-rebuild switch --flake .

# Test claude-code functionality
claude --version
```

## PR review notes

- CI validates flake structure and build.
- Review the complete `flake.lock` diff from Renovate.
- Merge only after the repository's required checks pass.
