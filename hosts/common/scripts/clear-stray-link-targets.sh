# shellcheck shell=bash
# Clear unmanaged symlinks sitting at home-manager-managed paths.
#
# Sourced into the home-manager activation DAG ahead of `checkLinkTargets` by
# ../hm-collision-clear.nix, which is where the rationale lives. Reads
# $newGenPath, $HOME and $DRY_RUN_CMD from the activation environment.

# `home-files` is a one-level symlink into the store; plain readlink resolves it
# under both GNU and BSD userlands (BSD readlink has no -e).
strayNewGenFiles="$(readlink "$newGenPath/home-files")"

while IFS= read -r -d '' straySource; do
  strayTarget="$HOME/${straySource#"$strayNewGenFiles"/}"
  [ -L "$strayTarget" ] || continue

  strayLink="$(readlink "$strayTarget")"
  # A link into a home-manager generation is home-manager's own; it relinks it.
  case "$strayLink" in
  /nix/store/*-home-manager-files/*) continue ;;
  esac

  echo "clearing unmanaged symlink in the way of home-manager: $strayTarget -> $strayLink" >&2
  $DRY_RUN_CMD rm -f "$strayTarget"
done < <(find "$strayNewGenFiles" \( -type f -o -type l \) -print0)
