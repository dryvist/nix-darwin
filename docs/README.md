# Documentation

Comprehensive documentation for the Nix configuration repository.

## Installation

Nothing to install here — this directory is a set of plain markdown
reference documents, not runnable code. To apply the nix-darwin
configuration these documents describe, see the [root README](../README.md)
and [SETUP.md](../SETUP.md).

## Usage

Browse the files below by topic, or search this directory for the term
you need. Each file is self-contained; no build step is required to read
them.

## Files

- **[ANTHROPIC-ECOSYSTEM.md](ANTHROPIC-ECOSYSTEM.md)** - Complete reference for the integrated Anthropic Claude Code ecosystem
  - Architecture overview and flake inputs
  - Plugin marketplace management
  - Commands, agents, and skills catalog
  - SDK development shells usage
  - GitHub Actions templates
  - Troubleshooting and maintenance

- **[LAUNCHD-SELF-HEAL.md](LAUNCHD-SELF-HEAL.md)** - Auto-reload of penalty-boxed critical KeepAlive daemons
  - The launchd penalty-box failure mode (loaded-but-not-running)
  - How the post-activation self-heal reloads dead daemons
  - Manual recovery (bootout/bootstrap, never kickstart)

- **[FILE-EXTENSIONS.md](FILE-EXTENSIONS.md)** - Custom file extension mappings for macOS
  - Configure non-standard archive extensions (e.g., .spl, .crbl)
  - Enable Finder auto-extract and shell autocomplete
  - UTI (Uniform Type Identifier) reference
  - Examples and troubleshooting

- **[MACOS-LLM-PERFORMANCE-TUNING-REPORT.md][mac-studio-report]** - Point-in-time Mac Studio benchmark and tuning report
  - Baseline vs current live measurements
  - Merged tuning PRs and activation caveat
  - Memory budget and eval guard

- **[MAC-STUDIO-SERVING-BASELINE-2026-07.md](MAC-STUDIO-SERVING-BASELINE-2026-07.md)** - jevans-ms LLM serving baseline snapshot (2026-07-06/07)
  - Config-as-committed vs. config-as-deployed drift (merged PRs pending `darwin-rebuild switch`)
  - Per-model benchmark table (cold-start, TTFT, decode/prefill tok/s, concurrency 2/4/8)
  - Concurrency, cold-start/preload, and max-context findings with concrete recommendations

## Related Documentation

Main repository documentation is in the root directory:

- **[README.md](../README.md)** - Repository overview and quick start
- **[CLAUDE.md](../CLAUDE.md)** - AI agent instructions and guidelines
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - System architecture and design patterns
- **[SETUP.md](../SETUP.md)** - Setup and installation guide
- **[TROUBLESHOOTING.md](../TROUBLESHOOTING.md)** - Common issues and solutions

## Contributing

See root-level documentation for contribution guidelines and workflows.

[mac-studio-report]: MACOS-LLM-PERFORMANCE-TUNING-REPORT.md
