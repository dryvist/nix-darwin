#!/usr/bin/env bash
# sandbox-clone — clone a fresh repository into the /Volumes/git sandbox workspace.
#
# Clones using an ephemeral token minted at call time from OpenBao, without
# touching ~/git and without writing credentials to disk or git config.
# Passes authentication strictly via GIT_CONFIG extraHeader (never in URL or argv).
# Confines repositories to the calling identity's private sandbox directory (/Volumes/git/<user>).
#
# Usage:
#   sandbox-clone <owner>/<repo> [dest_name]
#   sandbox-clone dryvist/tofu-proxmox
#   sandbox-clone dryvist/ansible-proxmox-apps apps

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: sandbox-clone <owner>/<repo> [dest_name]" >&2
  exit 1
fi

target="$1"

# Strict syntax validation: exactly one slash and valid GitHub name characters
if ! [[ "$target" =~ ^([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)$ ]]; then
  echo "error: target must be in '<owner>/<repo>' format, got: $target" >&2
  exit 1
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"

# Verify /Volumes/git exists and is not a symlink
if [ ! -d "/Volumes/git" ] || [ -L "/Volumes/git" ]; then
  echo "error: /Volumes/git must exist as a real directory and cannot be a symlink" >&2
  exit 1
fi

current_user="$(id -un)"
user_workspace="/Volumes/git/${current_user}"

# Verify user workspace root exists and is not a symlink (pre-created by nix-darwin activation)
if [ ! -d "$user_workspace" ] || [ -L "$user_workspace" ]; then
  echo "error: user workspace root does not exist or is a symlink: $user_workspace" >&2
  exit 1
fi

workspace_canonical="$(cd -P "$user_workspace" && pwd -P)"

# Destination handling: allow either a single safe directory name or an explicit path starting with user_workspace
dest_arg="${2:-$repo}"

if [[ "$dest_arg" == "${user_workspace}/"* ]]; then
  dest_name="${dest_arg#"${user_workspace}/"}"
elif [[ "$dest_arg" == "${workspace_canonical}/"* ]]; then
  dest_name="${dest_arg#"${workspace_canonical}/"}"
else
  dest_name="$dest_arg"
fi

# Strict single-component directory validation: no slashes, no dots, valid characters only
if ! [[ "$dest_name" =~ ^[a-zA-Z0-9_.-]+$ ]] || [[ "$dest_name" == "." ]] || [[ "$dest_name" == ".." ]]; then
  echo "error: destination directory name must be a single safe directory name within ${user_workspace}, got: $dest_arg" >&2
  exit 1
fi

dest_canonical="${workspace_canonical}/${dest_name}"

# Reject if destination is or points to a symlink
if [ -L "$dest_canonical" ]; then
  echo "error: destination cannot be a symlink: $dest_canonical" >&2
  exit 1
fi

# Mint ephemeral token strictly at call time from OpenBao (never accept ambient GH_TOKEN)
token=""
if command -v openbao-github-creds >/dev/null 2>&1; then
  token="$(openbao-github-creds token read "$owner" 2>/dev/null || true)"
fi

if [ -z "$token" ]; then
  echo "error: could not obtain ephemeral GitHub token for $owner from OpenBao" >&2
  exit 1
fi

if [ -d "$dest_canonical/.git" ]; then
  echo "[sandbox-clone] repository already exists at $dest_canonical; fetching updates"
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0="http.extraHeader" \
  GIT_CONFIG_VALUE_0="Authorization: Bearer ${token}" \
  git -C "$dest_canonical" fetch --prune origin
else
  echo "[sandbox-clone] cloning $target to $dest_canonical"
  # Use GIT_CONFIG extraHeader so the token is passed in memory env only:
  # - Never in argv (invisible in ps aux)
  # - Never in git clone URL
  # - Never persisted into .git/config
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0="http.extraHeader" \
  GIT_CONFIG_VALUE_0="Authorization: Bearer ${token}" \
  git clone --quiet "https://github.com/${owner}/${repo}.git" "$dest_canonical"
fi

# Enforce strictly private owner-only permissions (mode 0700) unmasked
chmod -R 0700 "$dest_canonical"

echo "[sandbox-clone] ready at $dest_canonical"
