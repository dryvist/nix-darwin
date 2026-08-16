# Architecture

> **Note**: This repo is part of a trio. See also
> [nix-ai](https://github.com/JacobPEvans/nix-ai) and
> [nix-home](https://github.com/JacobPEvans/nix-home)
> for AI tools and dev environment documentation.

Detailed structure of the nix-darwin configuration.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Module Relationships](#module-relationships)
- [Configuration Layers](#configuration-layers)

---

## Directory Structure

```text
~/.config/nix/
├── flake.nix                      # Main entry point
├── flake.lock                     # Locked dependency versions
│
├── hosts/                         # Host-specific configurations
│   └── macbook-m4/                # Active: M4 Max MacBook Pro
│       ├── default.nix            # Darwin system settings
│       └── home.nix               # User environment (packages, volumes)
│
├── modules/                       # Reusable configuration modules
│   └── darwin/
│       ├── common.nix             # macOS system packages, homebrew, settings
│       ├── apps/                  # Application-specific modules
│       │   ├── default.nix        # App module aggregator
│       │   ├── orbstack.nix       # OrbStack APFS volume management
│       │   ├── raycast.nix        # Raycast configuration
│       │   ├── auto-update-prevention.nix # Prevent unwanted app updates
│       │   └── scripts/           # App support scripts
│       ├── dock/                  # Dock configuration
│       │   ├── default.nix        # Dock behavior, appearance, hot corners
│       │   └── persistent-apps.nix # Dock app order (left & right sides)
│       ├── finder.nix             # Finder preferences
│       ├── keyboard.nix           # Keyboard settings
│       ├── trackpad.nix           # Trackpad gestures
│       ├── system-ui.nix          # Menu bar, control center, login window
│       ├── security.nix           # System security policies
│       ├── energy.nix             # Power management
│       ├── logging.nix            # Syslog forwarding
│       ├── boot-activation.nix    # Creates /run/current-system at boot
│       ├── launchd-bootstrap.nix  # LaunchDaemon bootstrap
│       ├── file-extensions.nix    # File type associations
│       ├── file-associations.nix  # File association helpers
│       ├── auto-recovery.nix      # Activation error recovery
│       ├── activation-error-tracking.nix # Track activation errors
│       └── homebrew.nix           # Homebrew casks and formulas
│
├── lib/                           # Shared configuration variables
│   ├── user-config.nix            # User info (name, email, GPG key)
│   ├── home-manager-defaults.nix  # Shared home-manager settings
│   └── checks.nix                 # Flake check definitions
│
├── ARCHITECTURE.md                # This file - detailed structure
├── CLAUDE.md                      # AI agent instructions
├── README.md                      # Project overview
├── REFERENCES.md                  # External documentation links
├── RUNBOOK.md                     # Operational procedures
├── SETUP.md                       # Initial setup guide
└── TROUBLESHOOTING.md             # Common issues and solutions
```

## Module Relationships

```text
flake.nix
    │
    ├── darwinConfigurations.default
    │       │
    │       ├── hosts/macbook-m4/default.nix
    │       │       └── imports: modules/darwin/common.nix
    │       │                       ├── modules/darwin/apps/
    │       │                       ├── modules/darwin/dock/
    │       │                       ├── modules/darwin/finder.nix
    │       │                       ├── modules/darwin/keyboard.nix
    │       │                       ├── modules/darwin/trackpad.nix
    │       │                       ├── modules/darwin/system-ui.nix
    │       │                       ├── modules/darwin/security.nix
    │       │                       ├── modules/darwin/energy.nix
    │       │                       └── modules/darwin/homebrew.nix
    │       │
    │       └── home-manager
    │               └── hosts/macbook-m4/home.nix
    │                           (AI tools via nix-ai, dev env via nix-home)
    │
    └── inputs
            ├── nix-ai       → AI coding tools (Claude, Gemini, etc.)
            └── nix-home     → Dev environment (git, zsh, VS Code, tmux)
```

## Configuration Layers

| Layer | Scope | Location | Managed By |
| --- | --- | --- | --- |
| System | macOS settings, packages | `modules/darwin/` | nix-darwin |
| User | AI tools, dev env, activation helpers | nix-ai, nix-home (flake inputs) | home-manager |
| Host | Machine-specific | `hosts/<name>/` | Both |
| Shared | Variables, defaults | `lib/` | Imported |

## Getting a nix-ai (or nix-home) change onto a Mac: the promotion contract

This repo's `nix-ai` input tracks nix-ai's **`main`** branch, not `develop`
(`github:dryvist/nix-ai/main` in `flake.nix`). Merging a PR into nix-ai's
`develop` does not make that change reachable by any Mac here — three
separate steps have to happen, in order:

1. **Promote nix-ai `develop` → `main`.** Only commits on nix-ai's `main`
   exist as far as this repo's `nix-ai` input is concerned.
2. **Bump this repo's `flake.lock`** (`nix flake update nix-ai` or
   equivalent) to pin the new nix-ai `main` revision.
3. **Promote this repo's own `develop` → `main`**, since a Mac converges
   from `main`.

Skipping any one of the three produces the exact same symptom: the change
looks merged (visible in nix-ai's `develop`, or even its `main`) but no
`darwin-rebuild switch` on any Mac ever picks it up. This gap has caused a
real merged-but-not-deployed incident more than once — treat "merged" and
"deployed" as separate questions and verify both.

**Operational note:** step 1's `main` promotion may or may not trigger a
release-please version-bump follow-on PR in nix-ai, depending on whether the
promoted commits carry a releasable conventional-commit type (`feat`/`fix`
bump; `docs`/`chore`/`refactor`/`test`/`ci` do not). When it does, `main`
gains a further commit after the promotion lands. **Converging to "the tip
of nix-ai's main" means converging to whatever tip exists after that PR
resolves, not the tip at the moment the promotion PR merged** — check
`main`'s actual head before pinning step 2, not the promotion PR's merge
commit.

For a complete list of installed packages and managed settings, see [MANIFEST.md](MANIFEST.md).
