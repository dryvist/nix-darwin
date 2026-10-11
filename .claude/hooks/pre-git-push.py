#!/usr/bin/env python3
"""
Pre-git-push hook: Requires darwin-rebuild before pushing (if .nix files changed).

This hook runs before Bash commands. If it's a git push AND .nix files
were modified, it runs darwin-rebuild first and blocks the push if it fails.

Exit codes:
  0 = allow the command
  2 = block the command (shows stderr to Claude)

Input: JSON from stdin with tool_input.command containing the Bash command
Output: Exit code determines whether command proceeds
"""

import json
import os
import subprocess
import sys


def is_nix_config_repo():
    """Check if the current repository is the nix-darwin repository."""
    try:
        # Get the remote origin URL
        result = subprocess.run(
            ["git", "config", "--get", "remote.origin.url"],
            capture_output=True,
            text=True,
            check=True,
        )
        remote_url = result.stdout.strip()

        # This is more robust than checking the local path as it works for any
        # clone location and handles both SSH and HTTPS remote URLs.
        return remote_url.endswith("dryvist/nix-darwin.git") or remote_url.endswith("dryvist/nix.git")
    except subprocess.CalledProcessError:
        # Git command failed (not in a git repo, no remote configured, etc.)
        return False
    except FileNotFoundError:
        # Git executable not found
        return False


def has_nix_changes():
    """Check if any .nix files were modified in commits being pushed."""
    try:
        # Get the upstream tracking branch
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            # No upstream, compare against origin/main
            upstream = "origin/main"
        else:
            upstream = result.stdout.strip()

        # Get list of changed files between upstream and HEAD
        # Use -z to handle filenames with spaces/newlines robustly
        result = subprocess.run(
            ["git", "diff", "-z", "--name-only", upstream, "HEAD"],
            capture_output=True,
        )
        if result.returncode != 0:
            # If diff fails, be conservative and run the check
            return True

        changed_files_bytes = result.stdout.strip(b'\0').split(b'\0')
        return any(f.endswith(b".nix") for f in changed_files_bytes if f)
    except (OSError, subprocess.SubprocessError):
        # On subprocess/OS errors, be conservative and run the check
        return True


def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        # No valid input, allow command
        return 0

    # Get the command being executed
    command = hook_input.get("tool_input", {}).get("command", "")

    # Only act on git push commands
    if "git push" not in command:
        return 0

    # Skip hook for non-nix-darwin repositories
    if not is_nix_config_repo():
        return 0

    # Skip darwin-rebuild in CI/automated workflows
    ci_markers = ["CI", "GITHUB_ACTIONS", "AUTOMATED_WORKFLOW"]
    is_automated = any(os.environ.get(marker) for marker in ci_markers)

    if is_automated:
        print("\n" + "═" * 64)
        print("⚠️  Pre-push: Automated workflow detected, skipping darwin-rebuild")
        print("    CI will perform full build verification")
        print("═" * 64 + "\n", flush=True)
        return 0

    # Skip if no .nix files were changed
    if not has_nix_changes():
        print("\n" + "═" * 64)
        print("⏭️  Pre-push: No .nix files changed, skipping darwin-rebuild")
        print("═" * 64 + "\n", flush=True)
        return 0

    # Run darwin-rebuild build (dry-run, no system changes)
    print("\n" + "═" * 64)
    print("🔨 Pre-push: .nix files changed, validating build...")
    print("═" * 64 + "\n", flush=True)

    try:
        result = subprocess.run(
            ["darwin-rebuild", "build", "--flake", "."],
            check=True,
            capture_output=True,
            text=True,
            timeout=600,
        )
        print("✅ darwin-rebuild build succeeded\n", flush=True)
        return 0
    except subprocess.TimeoutExpired:
        print("\n" + "═" * 64, file=sys.stderr)
        print("❌ Pre-push BLOCKED: darwin-rebuild timed out (>10 minutes)", file=sys.stderr)
        print("    Run manually: darwin-rebuild build --flake .", file=sys.stderr)
        print("═" * 64 + "\n", file=sys.stderr, flush=True)
        return 2
    except subprocess.CalledProcessError as e:
        print("\n" + "═" * 64, file=sys.stderr)
        print("❌ Pre-push BLOCKED: darwin-rebuild build failed", file=sys.stderr)
        print("    Fix the build errors before pushing:", file=sys.stderr)
        print(e.stderr, file=sys.stderr)
        print("═" * 64 + "\n", file=sys.stderr, flush=True)
        return 2
    except FileNotFoundError:
        print("\n" + "═" * 64, file=sys.stderr)
        print("⚠️  Pre-push WARNING: darwin-rebuild not found", file=sys.stderr)
        print("    Skipping validation (non-Darwin system?)", file=sys.stderr)
        print("═" * 64 + "\n", file=sys.stderr, flush=True)
        return 0


if __name__ == "__main__":
    sys.exit(main())
