# macOS-specific setup and cleanup

# Set tabs to 2 spaces
tabs -2

# Homebrew: update + doctor once per day; outdated versions on every start.
_brew_dir="${TMPDIR:-/tmp}/brew" && mkdir -p "$_brew_dir"
_brew_stamp="$_brew_dir/daily_$(date +%Y%m%d)"
if [[ ! -f "$_brew_stamp" ]]; then
  brew update && touch "$_brew_stamp"
  brew doctor
fi
HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --verbose
unset _brew_dir _brew_stamp

# Clean up .DS_Store files in common directories.
# Single find across all dirs; -exec rm {} + batches args for fewer rm invocations.
# Runs in the background to avoid blocking shell startup.
{ find ~/.config/ "${GIT_HOME}/" ~/obsidian/ -name ".DS_Store" -depth -exec rm {} + 2>/dev/null; } &!
