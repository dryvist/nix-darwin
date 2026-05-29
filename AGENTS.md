# Nix Configuration - AI Agent Instructions

## Repository Purpose

macOS system configuration managed with nix-darwin and Nix flakes (Determinate Nix).
Orchestrates system packages, networking, security, and home-manager via three companion repos (nix-ai, nix-home, nix-devenv).

## Critical Constraints

1. **Flakes-only**: Never use `nix-env`, `nix-channels`, or imperative commands
2. **Determinate Nix**: Use `determinateNix.enable = true` via the official module
   (`modules/darwin/nix-storage.nix`) — do not manually set `nix.enable = false`,
   the module handles this automatically; use `nix` (Determinate), not `nix-env` or `nix-channel`
3. **Nixpkgs first**: Use homebrew only when nixpkgs unavailable; prefer `pkgs.*` over overlays or custom derivations
4. **Worktrees required**: Run `/init-worktree` before any work
5. **No direct main commits**: Always use feature branches via PRs

## Build & Validate

Build validation is enforced by **GitHub Actions CI** (`ci-gate.yml`) on every PR — not by a local pre-push hook.

Local quick checks (formatting, linting, dead code) run automatically on every commit via pre-commit hooks:

```bash
nix flake check         # full flake check (run in CI)
nix fmt                 # format all Nix files (nixfmt-tree)
statix check            # static analysis
deadnix                 # dead code detection
```

A full `nix flake check && sudo darwin-rebuild switch --flake .` is run by CI on macOS runners and must
pass before merge. You may run it locally to verify before pushing, but it is not required locally.

## File Conventions

- `.nix` files: Nix expression language only
- Modules follow `{ config, pkgs, lib, ... }:` function pattern
- Use `lib.mkOption` for configurable options
- Attribute sets use `{}` not record syntax

## Common Patterns

```nix
# Module definition
{ config, pkgs, lib, ... }: {
  options.my.option = lib.mkEnableOption "description";
  config = lib.mkIf config.my.option { ... };
}
```

## Worktree Workflow

```bash
cd ${GIT_HOME_PUBLIC}/nix-darwin
git fetch origin
git worktree add <branch> -b <branch> origin/main
cd <branch>
```

## File References

- **Rules**: `agentsmd/rules/` (worktrees, version-validation, skill-namespace-resolution, security-alert-triage)
- **Security**: See SECURITY.md and `agentsmd/rules/security-alert-triage.md` for alert policies
- **Inventory**: `MANIFEST.md` — update when adding/removing packages

## Separation Guidelines

### What belongs here (nix-darwin)

- macOS system defaults (Dock, Finder, keyboard, trackpad, energy)
- Homebrew configuration (casks and brews not in nixpkgs)
- System-level packages (`environment.systemPackages`): core bootstrapping (git, gnupg, vim),
  macOS-only tools (mas, mactop), audio libs, GUI apps
- Security settings (firewall, Gatekeeper)
- LaunchDaemons (system-level services)
- Activation scripts and boot recovery
- Networking configuration

### What does NOT belong here

- User dev tools (bat, ripgrep, jq, etc.) -> nix-home (`home.packages`)
- Shell config (zsh, git aliases) -> nix-home
- Editor settings -> nix-home
- Linters and formatters -> nix-home
- AI tools (Claude, Gemini, Copilot, MCP) -> nix-ai
- User-level LaunchAgents -> nix-home

### Package placement

See the `nix-package-placement` rule — lives in
[ai-assistant-instructions][nix-pkg-placement] and auto-loads via
path-scoping when `.nix` / `flake.*` files are in context.

[nix-pkg-placement]: https://github.com/JacobPEvans/ai-assistant-instructions/blob/main/agentsmd/rules/nix-package-placement.md
Contains the full decision matrix for the nix repos including homebrew constraints
and on-demand patterns.

## Related Repos

| Repo | Scope | Used via |
| ---- | ----- | -------- |
| **nix-darwin** (this repo) | macOS system config (Dock, Finder, Homebrew, security) | nix-darwin |
| [nix-ai](https://github.com/dryvist/nix-ai) | AI CLI ecosystem (Claude, Gemini, Copilot, MCP) | home-manager |
| [nix-devenv](https://github.com/dryvist/nix-devenv) | Reusable dev shells (Terraform, Ansible, K8s, AI/ML) | nix develop |
| [nix-home](https://github.com/dryvist/nix-home) | User environment (dotfiles, dev tools, LaunchAgents) | home-manager |

## PR Rules

- Never auto-merge without explicit user approval
- 50-comment limit per PR
- Batch commits locally, push once

## Tooling baseline (inherited from dryvist/.github)

- **Markdown lint:** `markdownlint-cli2` with the canonical
  `.markdownlint-cli2.yaml` synced from
  [`dryvist/.github`](https://github.com/dryvist/.github).
  `MD013 line_length: 160`; no 80-char heading/code restrictions.
  `CHANGELOG.md`, `.github/aw/**`, and `worktrees/**` are ignored.
  `MD024` strict-by-default everywhere actually linted — never disabled
  across the board.
- **Pre-commit hooks**: see `.pre-commit-config.yaml`. Stack:
  `pre-commit/pre-commit-hooks@v6.0.0` meta-pack,
  `DavidAnson/markdownlint-cli2@v0.22.1`,
  `gitleaks/gitleaks@v8.30.1`,
  `zizmorcore/zizmor-pre-commit`,
  `semgrep/pre-commit`, plus local `nixfmt`, `statix`, `deadnix`,
  `lychee`, and repo-specific validators.
- **Out of scope for the current canonical-alignment PR**: adopting the
  `nix-devenv` `flakeModules.dev-hygiene` module requires migrating
  this flake from traditional outputs to `flake-parts` — a larger
  architectural change tracked separately. Same with switching
  `nixpkgs.url` to `nixos-unstable` (high-risk runtime change for the
  user's primary machine config).

Do NOT commit local copies of `.markdownlint-cli2.{jsonc,yaml}` that
drift from the dryvist canonical, and do NOT re-introduce leniency
rules to work around stale tooling.

## Secrets

**sops-nix** handles secrets that system activation scripts need (e.g. service enrollment
tokens for LaunchDaemons). Age-encrypted YAML files live in `secrets/` and are committed to
git. sops-nix decrypts them to root-only files under `/run/secrets/` at activation time.
The age private key stays at `~/.config/sops/age/keys.txt` and is never committed.

**Doppler** is used for general developer secrets (API keys, service credentials) accessed
from the user session. Never use Doppler CLI from within nix-darwin activation scripts —
activation runs as root without Keychain access. Use sops-nix instead.
