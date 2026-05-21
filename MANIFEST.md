# Manifest

> **Note**: This repo is part of a trio. See also
> [nix-ai](https://github.com/JacobPEvans/nix-ai) and
> [nix-home](https://github.com/JacobPEvans/nix-home)
> for AI tools and dev environment documentation.

Complete inventory of everything installed and managed by this nix-darwin configuration.
Each entry lists the source file where it is declared.

---

## System Packages (nixpkgs)

### Core CLI Tools

Source: `modules/darwin/common.nix`

| Package | Description |
|---------|-------------|
| git | Version control |
| gnupg | GPG encryption and signing |
| vim | Text editor |

### Modern CLI Tools

Source: `modules/darwin/common.nix`

| Package | Description |
|---------|-------------|
| bat | Better cat with syntax highlighting |
| delta | Better git diff viewer with syntax highlighting |
| eza | Modern ls replacement with git integration |
| fd | Faster, user-friendly find alternative |
| fzf | Fuzzy finder for interactive selection |
| gnugrep | GNU grep with zgrep for compressed files |
| gnutar | GNU tar as gtar (Mac-safe tar without .\_ files) |
| btop | Modern process monitor with graphs (daily use) |
| htop | Interactive process viewer |
| mactop | Real-time Apple Silicon CPU/GPU/ANE/thermal monitoring |
| jq | JSON parsing |
| ncdu | NCurses disk usage analyzer |
| ngrep | Network packet grep |
| ripgrep | Fast grep alternative (rg) |
| tldr | Simplified, community-driven man pages |
| tree | Directory tree visualization |
| watchexec | File watcher that re-executes commands on changes |
| yq | YAML/XML/TOML parsing (like jq) |
| sox | Audio recording, conversion, and effects (Sound eXchange) |
| portaudio | Cross-platform audio I/O library |

### Development Tools

Source: `modules/darwin/common.nix`

| Package | Description |
|---------|-------------|
| mas | Mac App Store CLI |

---

## Cross-Platform Packages

Source: nix-home (`home.packages` via flake input)

### Runtimes

| Package | Description |
|---------|-------------|
| bun | Fast all-in-one JavaScript runtime (provides bunx) |

### Git Workflow

| Package | Description |
|---------|-------------|
| git-flow-next | Modern git-flow workflow tool (custom buildGoModule, gittower/git-flow-next v1.0.0) |
| git-bug | Distributed bug tracker embedded in git (`git bug` command) |

### Pre-commit and Linters

| Package | Description |
|---------|-------------|
| pre-commit | Git pre-commit hook framework |
| shellcheck | Shell script static analysis |
| shfmt | Shell script formatter |
| lychee | Link checker for markdown and HTML (global: pre-commit language: system) |
| markdownlint-cli2 | Markdown linter |

### Nix Tooling

| Package | Description |
|---------|-------------|
| nixfmt-rfc-style | Official Nix formatter (RFC 166) |
| statix | Nix linter - catches anti-patterns |
| deadnix | Find unused code in .nix files |
| treefmt | Multi-language formatter runner |
| nix-tree | Browse Nix store dependencies interactively |
| check-jsonschema | JSON Schema validator CLI |

### Security and Credentials

| Package | Description |
|---------|-------------|
| bitwarden-cli | CLI for Bitwarden password manager (bw) |
| bws | Bitwarden Secrets Manager CLI |
| doppler | Doppler secrets manager CLI |

### Remote Shell

| Package | Description |
|---------|-------------|
| mosh | Resilient mobile shell using UDP |

### Visualization & Diagramming

On-demand via `nix run nixpkgs#d2` and `nix run nixpkgs#mermaid-cli` — not installed globally.

### Python

| Package | Description |
|---------|-------------|
| pyright | Static type checker for Python (global: IDEs require it in PATH) |
| python314 | Python 3.14 (primary runtime) |
| uv | Fast Python package manager (also runs EOL versions) |
| python3.withPackages | Unified env: cryptography, pygithub + document-skills deps |

---

## GUI Applications - System Level

Source: `modules/darwin/common.nix`

| Package | Description |
|---------|-------------|
| bitwarden-desktop | Password manager desktop app |
| raycast | Productivity launcher (replaces Spotlight) |
| swiftbar | Menu bar customization |

Note: OrbStack installed via Homebrew cask (`greedy = true`) in `modules/darwin/homebrew.nix` for TCC permission stability.
The `programs.orbstack` module (`modules/darwin/apps/orbstack.nix`) still manages the APFS data volume via launchd.

---

## GUI Applications - User Level

Source: `hosts/macbook-m4/home.nix`

| Package | Description |
|---------|-------------|
| chatgpt | OpenAI ChatGPT desktop app |
| claudebar | Menu bar AI coding assistant quota monitoring |
| code-cursor | Cursor AI IDE (VS Code fork) |
| discord | Voice/video chat (copyApps for TCC camera/mic stability) |
| ffmpeg | Audio/video recording, conversion, streaming |
| ghostty-bin | Terminal emulator |
| rapidapi | Full-featured HTTP client |

---

## Homebrew

Source: `modules/darwin/homebrew.nix`

### Brews

| Package | Description |
|---------|-------------|
| ccusage | Claude Code usage analyzer |
| block-goose-cli | Block's Goose AI agent |
| gemini-cli | Google Gemini CLI (moved from nixpkgs) |
| whisperkit-cli | Swift native on-device speech recognition (Apple Silicon) |

### Casks

All casks use `greedy = true` so that `brew upgrade --greedy` (run by `brew autoupdate` every 30 hours
via LaunchAgent) always installs the latest version rather than deferring to built-in auto-updaters.

| Package | greedy | Description |
|---------|--------|-------------|
| obsidian | yes | Knowledge base / note-taking |
| shortwave | yes | AI-powered email client |
| wispr-flow | yes | AI-powered voice dictation |
| voiceink | yes | Voice-to-text app (local whisper) |
| claude | yes | Anthropic Claude desktop app (not in nixpkgs for Darwin) |
| claude-code | yes | Anthropic Claude Code CLI |
| codex | yes | OpenAI Codex CLI (moved from nixpkgs; migrated from homebrew/core to cask) |
| antigravity | yes | Google AI-powered IDE (Gemini 3) |
| lm-studio | yes | Local LLM inference UI + OpenAI-compatible API server |
| postman | yes | API development environment (moved from nixpkgs — version lag caused schema mismatch) |
| orbstack | yes | Container/Linux VM runtime — cask for TCC permission stability |
| microsoft-teams | yes | Teams desktop app (not available on Mac App Store) |
| firefox | yes | Mozilla Firefox browser — cask for TCC permission stability |

### Mac App Store

| App | ID |
|-----|-----|
| Toggl Track | 1291898086 |
| Monarch Money Tweaks | 6753774259 |
| Windows App | 1295203466 |
| Microsoft Word | 462054704 |
| Microsoft Excel | 462058435 |
| Microsoft PowerPoint | 462062816 |
| Microsoft Outlook | 985367838 |
| Microsoft OneNote | 784801555 |
| OneDrive | 823766827 |

---

## Services (External)

Managed by nix-darwin modules but installed externally (not via nixpkgs or Homebrew).

| Service | Source | Description |
|---------|--------|-------------|
| Cribl Edge | `modules/darwin/apps/cribl-edge.nix` | Log collection agent (installed via .pkg, Nix manages LaunchDaemon + ACLs) |

---

## macOS System Settings

| Category | Source | Key Settings |
|----------|--------|--------------|
| Dock | `modules/darwin/dock/` | App layout, behavior, appearance, hot corners |
| Finder | `modules/darwin/finder.nix` | Preferences |
| Keyboard | `modules/darwin/keyboard.nix` | Key repeat, input settings |
| Trackpad | `modules/darwin/trackpad.nix` | Gestures |
| System UI | `modules/darwin/system-ui.nix` | Menu bar, control center, login window |
| Security | `modules/darwin/security.nix` | System security policies |
| Energy | `modules/darwin/energy.nix` | Power management |
| Boot | `modules/darwin/boot-activation.nix` | Creates /run/current-system at boot |
| Logging | `modules/darwin/logging.nix` | Syslog forwarding to remote server |
| File Extensions | `modules/darwin/file-extensions.nix` | File type associations |
| Auto Recovery | `modules/darwin/auto-recovery.nix` | Activation error recovery |

---

## Claude MCP Servers (Host-Specific)

Source: `hosts/macbook-m4/home.nix`

Custom MCP server entries added to `programs.claude.mcpServers` at the host level.

| Server | Command | Description |
|--------|---------|-------------|
| splunk | `doppler-mcp splunk-mcp-connect` | Splunk REST API via mcp-remote, secrets injected by Doppler |

---
