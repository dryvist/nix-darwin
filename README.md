# nix-darwin

> macOS system configuration managed with nix-darwin and Nix flakes.

[![License][license-img]][license-link]

[![CI Gate][ci-gate-img]][ci-gate-link] [![Nix Build][nix-build-img]][nix-build-link] [![Markdown Lint][md-lint-img]][md-lint-link]

## What Is This?

A flakes-only, multi-host nix-darwin configuration: an M4 Max MacBook Pro
workstation and an always-on Mac Studio LLM server, both defined in a single
host registry (`lib/hosts.nix`). Manages macOS system-level settings: system
packages, Dock, Finder, keyboard, security, Homebrew, and LaunchDaemons --
all declaratively. User-level configuration (dotfiles, dev tools,
LaunchAgents) is layered on top via external home-manager modules consumed
as flake inputs.

## Prerequisites

- **macOS on Apple Silicon** (aarch64-darwin only -- x86 Mac is not supported)
- **Determinate Nix** installer: <https://install.determinate.systems>
- **git**

## Installation

```bash
# 1. Clone the repo
git clone https://github.com/JacobPEvans/nix-darwin.git $GIT_HOME_PUBLIC/nix-darwin
cd $GIT_HOME_PUBLIC/nix-darwin

# 2. Build and activate for the first time
sudo darwin-rebuild switch --flake .
```

## Usage

```bash
# Rebuild after config changes
d-r

# Search for a package
nix search nixpkgs <name>

# Rollback if something breaks
sudo darwin-rebuild --rollback
```

The `d-r` alias expands to `sudo darwin-rebuild switch --flake .` and handles
full system + home-manager activation in one step.
See [RUNBOOK.md](RUNBOOK.md) for detailed operational procedures.

## Supported Platforms

**aarch64-darwin only.** This configuration targets Apple Silicon Macs.
The quality checks (`nix flake check`) run cross-platform (Linux/x86 too),
but the Darwin configuration itself only builds and activates on aarch64-darwin.

## Pre-Commit Hooks

Formatting and linting run automatically on every commit via pre-commit hooks
(nixfmt, statix, deadnix). BATS shell tests run via `nix flake check`
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
│   ├── common/                # Config shared by every host
│   ├── macbook-m4/            # M4 Max MacBook Pro (workstation)
│   └── mac-studio/            # M4 Max Mac Studio (LLM server)
├── modules/                   # Reusable configuration modules
│   └── darwin/                # macOS system settings
├── overlays/                  # Nixpkgs overlays
├── scripts/                   # Build and CI scripts
├── lib/                       # Shared configuration variables
└── tests/                     # Shell and integration tests
```

Full details in [ARCHITECTURE.md](ARCHITECTURE.md).

## Inputs and Boundaries

This flake is the **system orchestrator**. It consumes external
`homeManagerModules.default` outputs as flake inputs and wires them into the
shared home-manager configuration; it does not own user-level dotfiles, dev
tools, or AI CLI settings -- those belong to whichever modules provide them.
Other foundational pieces:

| Component | What It Does |
| --------- | ------------ |
| **Determinate Nix** | Manages Nix itself -- daemon, updates, core config |
| **nix-darwin** | macOS packages, system settings, Homebrew integration |
| **home-manager** | Activation recovery, config symlinks, and Raycast scripts |
| **OpenBao** | General runtime secret store and injection path |
| **sops-nix** | Legacy bridge for the remaining repo-local encrypted values |

**Key Rule**: Use nixpkgs for everything. Homebrew is fallback only.

## Secrets Management

**OpenBao is the general replacement for SOPS.** Shared homelab values belong
there. SaaS/external credentials must use OpenBao or their designated runtime
credential provider, never SOPS.

**[sops-nix](https://github.com/Mic92/sops-nix)** is being retired. Its only
permitted end state is trivial sensitive data owned exclusively by this
repository and never consumed elsewhere. The remaining GitHub runner and
Hugging Face entries are migration debt, not examples to copy.

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

> Part of a [larger ecosystem of ~40 repos](https://docs.jacobpevans.com) — see how it all fits together.
