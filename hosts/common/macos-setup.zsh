# macOS-specific interactive shell setup

# Set tabs to 2 spaces
tabs -2

# Homebrew: nix-homebrew installs and manages brew, its taps, and the Brewfile
# declaratively — updates apply at darwin-rebuild time, so login runs NO brew
# commands. `brew update`/`brew doctor` only emit noise under nix-homebrew (the
# brew core has no git origin remote), and even a read-only `brew outdated` adds
# synchronous latency to every shell startup for a nudge Nix already owns. Run
# `brew outdated` by hand when you want it; the darwin-rebuild is the source of
# truth for what's installed.

# Per-shell work stays constant-time: this file runs for every interactive shell
# (each terminal tab, each agent session), so it never walks the filesystem.
# .DS_Store files are ignored by git globally and excluded by the `tgz` alias.
