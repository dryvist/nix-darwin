# nix-darwin

> macOS system configuration managed with nix-darwin and Nix flakes.

[![License][license-img]][license-link]

[![CI Gate][ci-gate-img]][ci-gate-link] [![Nix Build][nix-build-img]][nix-build-link] [![Markdown Lint][md-lint-img]][md-lint-link]

## What Is This?

A flakes-only nix-darwin configuration for M4 Max MacBook Pro. Manages macOS
system-level settings: system packages, Dock, Finder, keyboard, security,
Homebrew, and LaunchDaemons -- all declaratively. User-level configuration
(dotfiles, dev tools, LaunchAgents) is managed by nix-home and nix-ai,
imported as flake inputs.

**Part of a trio:**

| Repo | Scope | Installs via |
| ---- | ----- | ------------ |
| **nix-darwin** (this repo) | macOS system config (Dock, Finder, Homebrew, security) | nix-darwin |
| [nix-ai](https://github.com/JacobPEvans/nix-ai) | AI CLI ecosystem (Claude, Gemini, Copilot, MCP) | home-manager |
| [nix-home](https://github.com/JacobPEvans/nix-home) | User environment (dotfiles, dev tools, LaunchAgents) | home-manager |

## Prerequisites

- **macOS on Apple Silicon** (aarch64-darwin only -- x86 Mac is not supported)
- **Determinate Nix** installer: <https://install.determinate.systems>
- **git**

## Quick Start

### First-Time Setup

```bash
# 1. Clone as a bare repo (worktree convention used throughout ${GIT_HOME})
git clone --bare https://github.com/JacobPEvans/nix-darwin.git ${GIT_HOME_PUBLIC}/nix-darwin
cd ${GIT_HOME_PUBLIC}/nix-darwin

# 2. Create the main worktree
git worktree add main main

# 3. Build and activate for the first time
cd ${GIT_HOME_PUBLIC}/nix-darwin/main
sudo darwin-rebuild switch --flake .
```

### Subsequent Rebuilds

```bash
# Rebuild after config changes
d-r

# Search for a package
nix search nixpkgs <name>

# Rollback if something breaks
sudo darwin-rebuild --rollback
```

The `d-r` alias (defined in nix-home) expands to `sudo darwin-rebuild switch --flake .`
and handles full system + home-manager activation in one step.
See [RUNBOOK.md](RUNBOOK.md) for detailed operational procedures.

## Supported Platforms

**aarch64-darwin only.** This configuration targets Apple Silicon Macs.
The quality checks (`nix flake check`) run cross-platform (Linux/x86 too),
but the Darwin configuration itself only builds and activates on aarch64-darwin.

## Pre-Commit Hooks

Formatting and linting run automatically on every commit via pre-commit hooks
(nixfmt, statix, deadnix, shellcheck). BATS shell tests run via `nix flake check`
and CI -- not on each commit.

To install the hooks locally:

```bash
nix shell nixpkgs#pre-commit -c pre-commit install
```

## What It Manages

- **Nix packages** via nixpkgs (preferred over Homebrew)
- **macOS system defaults** (Dock, Finder, keyboard, trackpad, energy)
- **Homebrew** (fallback for casks not in nixpkgs)
- **Security settings** (firewall, Gatekeeper, stealth mode)
- **LaunchAgents** via nix-darwin launchd modules
- **Activation scripts** with error tracking and recovery

See **[MANIFEST.md](MANIFEST.md)** for the complete package inventory.

## Directory Structure

```text
.
├── flake.nix                  # Main entry point
├── hosts/                     # Host-specific configurations
│   └── macbook-m4/            # Active M4 Max MacBook Pro
├── modules/                   # Reusable configuration modules
│   └── darwin/                # macOS system settings
├── overlays/                  # Nixpkgs overlays
├── scripts/                   # Build and CI scripts
├── lib/                       # Shared configuration variables
└── tests/                     # Shell and integration tests
```

Full details in [ARCHITECTURE.md](ARCHITECTURE.md).

## Key Components

| Component | What It Does |
| --------- | ------------ |
| **Determinate Nix** | Manages Nix itself -- daemon, updates, core config |
| **nix-darwin** | macOS packages, system settings, Homebrew integration |
| **home-manager** | Activation recovery, config symlinks, and Raycast scripts |
| **mac-app-util** | Stable app trampolines to preserve TCC permissions |
| **[nix-ai](https://github.com/JacobPEvans/nix-ai)** | Shared home-manager modules for AI tools (Claude, Gemini, Copilot, MCP) |
| **[nix-home](https://github.com/JacobPEvans/nix-home)** | Shared home-manager modules for dev environment (git, zsh, VS Code, tmux) |
| **sops-nix** | Decrypts age-encrypted secrets to `/run/secrets/` for system services |

## Secrets Management

System-level secrets (used by LaunchDaemons and activation scripts) are managed via
**[sops-nix](https://github.com/Mic92/sops-nix)**. Encrypted YAML files live in `secrets/`
and are safe to commit. The age private key (`~/.config/sops/age/keys.txt`) is generated
once per machine and never committed.

**Doppler** is used for developer credentials accessed in the user session (Terraform state,
API tokens, etc.). Doppler CLI requires Keychain and cannot be called from activation scripts
(which run as root). sops-nix handles that boundary.

This repo is the **orchestrator**: it pulls in `nix-ai` and `nix-home` as flake inputs
and wires their `homeManagerModules.default` into the shared home-manager configuration.
Changes to AI tools or dev environment settings belong in those repos, not here.

**Key Rule**: Use nixpkgs for everything. Homebrew is fallback only.

## Documentation

| File | Purpose |
| ---- | ------- |
| [RUNBOOK.md](RUNBOOK.md) | Step-by-step operational procedures |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Detailed structure and module relationships |
| [MANIFEST.md](MANIFEST.md) | Complete inventory of packages and settings |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and solutions |
| [SETUP.md](SETUP.md) | Initial setup guide |
| [CLAUDE.md](CLAUDE.md) | AI agent instructions |

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

[MIT](LICENSE)

---

*Built by a human, refined by AI, used by both.*

<!-- Badge references -->
[license-img]: https://img.shields.io/badge/License-MIT-blue.svg
[license-link]: LICENSE
[ci-gate-img]: https://github.com/JacobPEvans/nix-darwin/actions/workflows/ci-gate.yml/badge.svg
[ci-gate-link]: https://github.com/JacobPEvans/nix-darwin/actions/workflows/ci-gate.yml
[nix-build-img]: https://github.com/JacobPEvans/nix-darwin/actions/workflows/ci-nix.yml/badge.svg
[nix-build-link]: https://github.com/JacobPEvans/nix-darwin/actions/workflows/ci-nix.yml
[md-lint-img]: https://github.com/JacobPEvans/nix-darwin/actions/workflows/ci-markdownlint.yml/badge.svg
[md-lint-link]: https://github.com/JacobPEvans/nix-darwin/actions/workflows/ci-markdownlint.yml
