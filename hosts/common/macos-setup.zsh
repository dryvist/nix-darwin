# macOS-specific setup and cleanup

# Set tabs to 2 spaces
tabs -2

# Homebrew: nix-homebrew installs and manages brew, its taps, and the Brewfile
# declaratively — updates apply at darwin-rebuild time, so login runs NO brew
# commands. `brew update`/`brew doctor` only emit noise under nix-homebrew (the
# brew core has no git origin remote), and even a read-only `brew outdated` adds
# synchronous latency to every shell startup for a nudge Nix already owns. Run
# `brew outdated` by hand when you want it; the darwin-rebuild is the source of
# truth for what's installed.

# Clean up .DS_Store files in common directories.
# Single find across all dirs; -exec rm {} + batches args for fewer rm invocations.
# Runs in the background to avoid blocking shell startup.
{ find ~/.config/ "$GIT_HOME/" ~/obsidian/ -name ".DS_Store" -depth -exec rm {} + 2>/dev/null; } &!
