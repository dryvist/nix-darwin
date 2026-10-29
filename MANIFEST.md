# Manifest

> **Note**: This repo has companion repos. See
> [nix-ai](https://github.com/dryvist/nix-ai),
> [nix-home](https://github.com/dryvist/nix-home), and
> [nix-devenv](https://github.com/dryvist/nix-devenv)
> for AI tools, dev environment, and dev shell documentation.

Complete inventory of everything installed and managed by this nix-darwin configuration.
Each entry lists the source file where it is declared.

---

## System Packages (nixpkgs)

### Core CLI Tools

Source: `modules/darwin/common.nix`

| Package | Description |
| --- | --- |
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

### Libraries

Source: `modules/darwin/common.nix`

| Package | Description |
| --- | --- |
| simdutf | SIMD UTF-8 validation library |

## Cross-Platform Packages

Source: nix-home (`home.packages` via flake input)

### Runtimes

| Package | Description |
| --- | --- |
| bun | Fast all-in-one JavaScript runtime (provides bunx) |

### Git Workflow

| Package | Description |
| --- | --- |
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

`mermaid-cli` stays on-demand via `nix run nixpkgs#mermaid-cli` — not installed globally.
`d2` is installed on macbook-m4 only (see `hosts/macbook-m4/home.nix`), so it's on PATH for
the Cursor D2 extension's live preview; other hosts still use `nix run nixpkgs#d2` on-demand.

### Python

| Package | Description |
| --- | --- |
| pyright | Static type checker for Python (global: IDEs require it in PATH) |
| python314 | Python 3.14 (primary runtime) |
| uv | Fast Python package manager (also runs EOL versions) |
| python3.withPackages | Unified env: cryptography, pygithub, pyyaml + document-skills deps |

---

## Workstation GUI applications

Source: `hosts/macbook-m4/home.nix`

Workstation GUI apps are Homebrew casks and Mac App Store apps under
`/Applications/`, plus Home Manager copies under `~/Applications/Home Manager Apps/`.

| Package | Description |
| --- | --- |
| code-cursor | Cursor AI IDE (VS Code fork) |
| discord | Voice/video chat (copyApps for TCC camera/mic stability) |
| firefox | Mozilla Firefox browser |
| ffmpeg | Audio/video recording, conversion, streaming |
| ghostty-bin | Terminal emulator |
| obsidian | Knowledge base / note-taking |
| rapidapi | Full-featured HTTP client |
| raycast | Productivity launcher |
| swiftbar | Menu bar customization |

Note: OrbStack installed via Homebrew cask (`greedy = true`) in `modules/darwin/homebrew.nix` for TCC permission stability.
The `programs.orbstack` module (`modules/darwin/apps/orbstack.nix`) still manages the APFS data volume via launchd.

## Darwin User CLI Packages

Source: nix-home (`modules/home-manager/darwin/default.nix` via flake input)

| Package | Description |
| --- | --- |
| langgraph-cli | LangGraph CLI |

---

## Homebrew

Source: `modules/darwin/homebrew.nix`

### Brews

| Package | Description |
| --- | --- |
| container | Apple container CLI/runtime for Linux containers on Apple Silicon |
| mas | Mac App Store command-line utility for managing App Store apps |
| node@22 | Versioned Node.js 22 runtime |
| whisperkit-cli | Swift native on-device speech recognition (Apple Silicon) |

### Casks

The weekly `brew-upgrade` LaunchAgent invokes `brew upgrade --greedy` every Thursday at 04:20 local time,
logging to `~/Library/Logs/brew-upgrade.log`. `darwin-rebuild` does not upgrade Homebrew packages
(`onActivation.upgrade = false`), and the agent does not upgrade Homebrew itself — the `brew` binary comes from the
`brew-src` flake input via `nix-homebrew`, so its version advances when the flake lock is refreshed and the host rebuilds.
Workstation Homebrew cleanup uses `check`: activation aborts and lists every
installed cask or formula not declared in the Nix configuration; it removes nothing.

| Package | greedy | Description |
| --- | --- | --- |
| slack | yes | Team chat desktop app |
| ghostty | yes | Terminal emulator — stable bundle for TCC permissions |
| bitwarden | yes | Password manager desktop app (moved from nixpkgs — EOL electron_39) |
| wispr-flow | yes | AI-powered voice dictation |
| granola | yes | AI-powered meeting notes |
| claudebar | yes | Claude Code menu bar utility |
| neat | yes | Neat device management app |
| claude-code@latest | no | Anthropic Claude Code CLI |
| codex | no | OpenAI Codex CLI (nix-ai's agent launcher execs it) |
| claude | yes | Anthropic Claude desktop app (workstation capability) |
| chatgpt | yes | OpenAI ChatGPT desktop app (workstation capability) |
| antigravity | yes | Google Antigravity 2.0 standalone agent command center (workstation capability) |
| antigravity-ide | yes | Google Antigravity IDE (workstation capability) |
| postman | yes | API development environment (moved from nixpkgs — version lag caused schema mismatch) |
| orbstack | yes | Container/Linux VM runtime — cask for TCC permission stability |
| microsoft-teams | yes | Teams desktop app (not available on Mac App Store) |
| libreoffice | yes | Office suite and `soffice` conversion tools |
| openwebstart | yes | Java Web Start replacement for iDRAC virtual-console files |

### Mac App Store

| App | ID |
| --- | --- |
| Monarch Money Tweaks | 6753774259 |
| Windows App | 1295203466 |
| Microsoft Word | 462054704 |
| Microsoft Excel | 462058435 |
| Microsoft PowerPoint | 462062816 |
| Microsoft Outlook | 985367838 |
| Yubico Authenticator | 1497506650 |
| OneDrive | 823766827 |

---

## Services (External)

Managed by nix-darwin modules but installed externally (not via nixpkgs or Homebrew).

| Service | Source | Description |
| --- | --- | --- |
| Cribl Edge | `modules/darwin/apps/cribl-edge.nix` | Log collection agent (installed via .pkg, Nix manages LaunchDaemon + ACLs) |
| llm-gate (Caddy) | `modules/darwin/llm-gate.nix` | API-only TLS + bearer gate for the LLM API (llm-large tier) on server hosts; sops-rendered Caddyfile |
| GitHub Actions Runner | `modules/darwin/apps/github-runner-container.nix` | Ephemeral org runner in an Apple `container` VM; env-driven image, PAT via sops |
| macOS VM GitHub Actions Runner | `modules/darwin/apps/macos-vm-runner.nix` | Ephemeral org runner per job in a Tart macOS VM (khoi/sand); root-only App key |

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
