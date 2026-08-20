# Manifest

> **Note**: This repo has companion repos. See
> [nix-ai](https://github.com/JacobPEvans/nix-ai),
> [nix-home](https://github.com/JacobPEvans/nix-home), and
> [nix-devenv](https://github.com/JacobPEvans/nix-devenv)
> for AI tools, dev environment, and dev shell documentation.

Complete inventory of everything installed and managed by this nix-darwin configuration.
Each entry lists the source file where it is declared.

---

## System Packages (nixpkgs)

### Core CLI Tools

Source: `modules/darwin/common.nix`

| Package | Description |
| --- | --- |
| entire | AI-session capture for git (records live agent sessions) |
| git | Version control |
| gnupg | GPG encryption and signing |
| vim | Text editor |

### Modern CLI Tools

Source: `modules/darwin/common.nix`

| Package | Description |
| --- | --- |
| bat | Better cat with syntax highlighting |
| delta | Better git diff viewer with syntax highlighting |
| eza | Modern ls replacement with git integration |
| fd | Faster, user-friendly find alternative |
| fzf | Fuzzy finder for interactive selection |
| gnugrep | GNU grep with zgrep for compressed files |
| gnutar | GNU tar as gtar (Mac-safe tar without .\_ files) |
| btop | Modern process monitor with graphs (daily use) |
| htop | Interactive process viewer |
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
| --- | --- |
| mas | Mac App Store CLI |

### Graphical Applications

Source: `modules/darwin/common.nix`

| Package | Description |
| --- | --- |
| gimp | GNU Image Manipulation Program photo editor |

---

## Cross-Platform Packages

Source: nix-home (`home.packages` via flake input)

### Runtimes

| Package | Description |
| --- | --- |
| bun | Fast all-in-one JavaScript runtime (provides bunx) |

### Git Workflow

| Package | Description |
| --- | --- |
| git-flow-next | Modern git-flow workflow tool (custom buildGoModule, gittower/git-flow-next v1.0.0) |
| git-bug | Distributed bug tracker embedded in git (`git bug` command) |

### Pre-commit and Linters

| Package | Description |
| --- | --- |
| pre-commit | Git pre-commit hook framework |
| shfmt | Shell script formatter |
| lychee | Link checker for markdown and HTML (global: pre-commit language: system) |
| markdownlint-cli2 | Markdown linter |

### Nix Tooling

| Package | Description |
| --- | --- |
| nixfmt-rfc-style | Official Nix formatter (RFC 166) |
| statix | Nix linter - catches anti-patterns |
| deadnix | Find unused code in .nix files |
| treefmt | Multi-language formatter runner |
| nix-tree | Browse Nix store dependencies interactively |
| check-jsonschema | JSON Schema validator CLI |

### Security and Credentials

| Package | Description |
| --- | --- |
| bitwarden-cli | CLI for Bitwarden password manager (bw) |
| bws | Bitwarden Secrets Manager CLI, pinned from Bitwarden's official release to avoid nixpkgs' Rust source rebuild |
| doppler | Doppler secrets manager CLI |

### Remote Shell

| Package | Description |
| --- | --- |
| mosh | Resilient mobile shell using UDP |

### Visualization & Diagramming

On-demand via `nix run nixpkgs#d2` and `nix run nixpkgs#mermaid-cli` — not installed globally.

### Python

| Package | Description |
| --- | --- |
| pyright | Static type checker for Python (global: IDEs require it in PATH) |
| python314 | Python 3.14 (primary runtime) |
| uv | Fast Python package manager (also runs EOL versions) |
| python3.withPackages | Unified env: cryptography, pygithub, pyyaml + document-skills deps |

---

## GUI Applications - User Level

Source: `hosts/macbook-m4/home.nix`

All workstation GUI apps are user-level via home-manager `copyApps`, which
copies them to `~/Applications/Home Manager Apps/` at TCC-stable paths.

| Package | Description |
| --- | --- |
| code-cursor | Cursor AI IDE (VS Code fork) |
| discord | Voice/video chat (copyApps for TCC camera/mic stability) |
| ffmpeg | Audio/video recording, conversion, streaming |
| ghostty-bin | Terminal emulator |
| rapidapi | Full-featured HTTP client |
| swiftbar | Menu bar customization |

Note: OrbStack installed via Homebrew cask (`greedy = true`) in `modules/darwin/homebrew.nix` for TCC permission stability.
The `programs.orbstack` module (`modules/darwin/apps/orbstack.nix`) still manages the APFS data volume via launchd.

---

## Homebrew

Source: `modules/darwin/homebrew.nix`

### Brews

| Package | Description |
| --- | --- |
| container | Apple container CLI/runtime for Linux containers on Apple Silicon |
| block-goose-cli | Block's Goose AI agent (shared CLI capability from nix-ai) |
| qwen-code | Alibaba Qwen Code agent (shared CLI capability from nix-ai) |
| whisperkit-cli | Swift native on-device speech recognition (Apple Silicon) |

### Casks

All casks use `greedy = true` so that `brew upgrade --greedy` always installs the latest version rather than deferring to built-in auto-updaters.

| Package | greedy | Description |
| --- | --- | --- |
| raycast | yes | Productivity launcher (moved from nixpkgs — version lag) |
| obsidian | yes | Knowledge base / note-taking |
| bitwarden | yes | Password manager desktop app (moved from nixpkgs — EOL electron_39) |
| wispr-flow | yes | AI-powered voice dictation |
| superwhisper | yes | Dictation with LLM reformatting |
| voiceink | yes | Voice-to-text app (local whisper) |
| claude | yes | Anthropic Claude desktop app (workstation capability) |
| claude-code@latest | yes | Anthropic Claude Code CLI (shared CLI cask on every host) |
| chatgpt | yes | OpenAI ChatGPT desktop app (moved from nixpkgs — version lag + no self-update) |
| codex-app | yes | OpenAI Codex desktop app (workstation capability; separate from the CLI) |
| codex | yes | OpenAI Codex CLI (shared CLI cask on every host) |
| antigravity-cli | yes | Google Antigravity CLI (`agy`; shared CLI cask on every host) |
| antigravity | yes | Google Antigravity 2.0 standalone agent command center (workstation capability) |
| antigravity-ide | yes | Google Antigravity IDE (workstation capability) |
| lm-studio | yes | Local LLM inference UI + OpenAI-compatible API server |
| postman | yes | API development environment (moved from nixpkgs — version lag caused schema mismatch) |
| orbstack | yes | Container/Linux VM runtime — cask for TCC permission stability |
| microsoft-teams | yes | Teams desktop app (not available on Mac App Store) |
| firefox | yes | Mozilla Firefox browser — cask for TCC permission stability |

### Mac App Store

| App | ID |
| --- | --- |
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
| --- | --- | --- |
| Cribl Edge | `modules/darwin/apps/cribl-edge.nix` | Log collection agent (installed via .pkg, Nix manages LaunchDaemon + ACLs) |
| llm-gate (Caddy) | `modules/darwin/llm-gate.nix` | API-only TLS + bearer gate for the LLM API (llm-large tier) on server hosts; sops-rendered Caddyfile |
| GitHub Actions Runner | `modules/darwin/apps/github-runner-container.nix` | Ephemeral org runner in an Apple `container` VM; env-driven image, PAT via sops |

---

## macOS System Settings

| Category | Source | Key Settings |
| --- | --- | --- |
| Dock | `modules/darwin/dock/` | App layout, behavior, appearance, hot corners |
| Finder | `modules/darwin/finder.nix` | Preferences |
| Keyboard | `modules/darwin/keyboard.nix` | Key repeat, input settings |
| Trackpad | `modules/darwin/trackpad.nix` | Gestures |
| System UI | `modules/darwin/system-ui.nix` | Menu bar, control center, login window |
| Security | `modules/darwin/security.nix` | System security policies |
| Energy | `modules/darwin/energy.nix` | Power management (sleep/wake timers) |
| Apple Silicon Tunables | `modules/darwin/apple-silicon-tunables.nix` | GPU wired limit, pmset perf, App Nap, Spotlight/TM excludes, Metal env |
| Resource Limits | `modules/darwin/system-limits.nix` | `kern.maxfiles*` / `maxproc` + `launchctl limit maxfiles` (524288) |
| Network Tuning | `modules/darwin/network-tuning.nix` | TCP/socket-buffer sysctls (exposed, off by default) |
| Boot | `modules/darwin/boot-activation.nix` | Creates /run/current-system at boot |
| Logging | `modules/darwin/logging.nix` | Syslog forwarding to remote server |
| File Extensions | `modules/darwin/file-extensions.nix` | File type associations |
| Auto Recovery | `modules/darwin/auto-recovery.nix` | Activation error recovery |

> Performance tuning: every macOS / M4 Max inference knob (wired memory, pmset, thermal, file
> limits, network) is catalogued in [docs/MACOS-LLM-PERFORMANCE-TUNING.md](docs/MACOS-LLM-PERFORMANCE-TUNING.md).

---

## AI MCP Servers (Shared)

Source: `hosts/common/home.nix`

The canonical `programs.aiMcp` registry renders the same MCP server set for
Claude, Codex, and the other local AI clients on every host.

| Server | Command | Description |
| --- | --- | --- |
| vikunja | `doppler-mcp bunx @democratize-technology/vikunja-mcp@<pinned>` | Vikunja task API, with credentials injected by Doppler |

---
