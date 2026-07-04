# macOS-specific setup and cleanup

# Set tabs to 2 spaces
tabs -2

# Homebrew: nix-homebrew now installs and manages brew, its taps, and the
# Brewfile declaratively (updates apply at darwin-rebuild time). So we do NOT
# run `brew update`/`brew doctor` on login: under nix-homebrew the brew core has
# no git origin remote, so those only emit noise ("Missing origin remote") and
# duplicate work Nix already owns. A quiet, no-auto-update `brew outdated` stays
# as an informational nudge. Gated on brew existing so a host without Homebrew
# (or before its first darwin-rebuild) stays silent instead of spewing
# "command not found: brew" on every shell startup.
if command -v brew >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --verbose
fi

# Clean up .DS_Store files in common directories.
# Single find across all dirs; -exec rm {} + batches args for fewer rm invocations.
# Runs in the background to avoid blocking shell startup.
{ find ~/.config/ "${GIT_HOME}/" ~/obsidian/ -name ".DS_Store" -depth -exec rm {} + 2>/dev/null; } &!
