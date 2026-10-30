# Contributing

Thanks for considering contributing. It's just me here, so any help is genuinely appreciated. 🙏

## The Short Version

1. Fork it
2. Create your feature branch (`git checkout -b feature/cool-thing`)
3. Commit your changes (GPG-signed—because apparently security matters)
4. Push to the branch (`git push origin feature/cool-thing`)
5. Open a Pull Request

That's it. I'm not picky—but Nix and pre-commit hooks are. They'll let you know if something's wrong. 😄

## Repository Standards

- **Commit Signing** – All commits must be GPG-signed.
- **PR Standards** – Use conventional commit format (`type(scope): description`) and apply type/priority/size labels.
- **Issue Linking** – Connect related issues with "Closes #123" or "Related to #123" in PR descriptions.
- **General Acceptance Criteria** – Improvements to documentation, bug fixes, and code maintainability are welcome.

## Reporting Issues

Found a bug? Something unclear? Open an issue. Describe what you expected, what happened instead, and any relevant context.

## Repository-Specific Guidelines

### Before You Start

- Check if there's already an issue or PR for what you're planning
- For big changes, maybe open an issue first to discuss

### Code Style

**Markdown:** Linted by `markdownlint-cli2` (runs automatically during pre-commit). It's surprisingly opinionated about spaces, but we roll with it.

**Nix Code:** Follow existing patterns. Comments are encouraged—this config is meant to be
educational. Comments help contributors understand the `nix-darwin` ecosystem. (Seriously,
verbose comments are a feature here, not a bug.)

See [docs/PRECOMMIT.md](docs/PRECOMMIT.md) for all automated checks that run on commit. They're there to protect you from yourself.

### What Might Not Get Accepted

- **Removing comments** (they're there for learning—and also for my sanity 6 months from now)
- **Unnecessary complexity** (this isn't a code golf competition; clarity wins)
- **Nix-env or channels** (we're flakes-only here, and we're keeping it that way)

## Development Setup

### Prerequisites

This repository requires:

1. **Nix** (latest, via Determinate installer recommended)
2. **Git** (for committing and pushing)
3. **macOS** (nix-darwin is macOS-specific)

### Initial Setup

```bash
# 1. Clone the repo
git clone <repo-url>
cd nix-darwin

# 2. Install pre-commit hooks (automatic on rebuild)
pre-commit install

# 3. Make changes to Nix files
# Edit files in modules/, hosts/, etc.

# 4. Test your changes locally
nix flake check

# 5. Commit (hooks run automatically)
git add .
git commit -m "Your change description"

# 6. Push to GitHub
git push origin your-branch
```

### Running Pre-commit Hooks

Before pushing, ensure all checks pass:

```bash
# Run all checks on all files (this is where the magic happens)
pre-commit run --all-files

# All passed? Congratulations, you're ready to push
git push
```

For detailed pre-commit documentation (because these hooks are surprisingly powerful), see [docs/PRECOMMIT.md](docs/PRECOMMIT.md), which explains:

- What each tool group does
- How to run hooks manually
- How to troubleshoot common issues
- Tool reference and documentation

### Rebuilding System Configuration

After your changes are committed, it's time to see if it actually works:

```bash
# Rebuild system with your changes (fingers crossed 🤞)
sudo darwin-rebuild switch --flake ~/.config/nix

# Rollback if something breaks (we've all been there)
sudo darwin-rebuild rollback
```

See [RUNBOOK.md](RUNBOOK.md) for more operational procedures and disaster recovery strategies.

## Questions?

Open an issue. I'll respond when I can. Or ping me on the Nix Slack if you're feeling spicy.

---

*Thanks for reading this far. Most people don't. You're a legend.* 🦸

### Shell Script Testing

Shell scripts in this repository are tested using **BATS** (Bash Automated Testing System).

#### Running Tests

```bash
# Run all shell script tests
./tests/run-shell-tests.sh

# Run tests matching a pattern
bats tests/shell/test_*.bats
```

#### Writing New Tests

Test files are stored in `tests/shell/` with the `.bats` extension. Each test file should focus on testing a single shell script or related functionality.

Basic BATS test structure:

```bats
#!/usr/bin/env bats
# Descriptive comment about what these tests cover

@test "descriptive test name" {
  run command_to_test arg1 arg2
  [ "$status" -eq 0 ]              # Assert exit code
  [[ "$output" =~ "expected text" ]] # Assert output contains text
}

@test "another test" {
  [ 1 -eq 1 ]  # Simple assertion
}
```

**Key BATS features:**

- `run` - Execute a command and capture output/exit code
- `$status` - Exit code from last `run` command
- `$output` - Captured stdout from last `run` command
- `[ ... ]` - Bash test assertions
- `[[ ... ]]` - Bash conditional expressions (pattern matching with `=~`)

For complete BATS documentation, see [bats-core documentation](https://bats-core.readthedocs.io/).
