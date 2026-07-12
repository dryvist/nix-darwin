# shellcheck shell=bash
# Runner for the check-shellcheck flake check (lib/checks.nix).
#
# Env contract (injected by the runCommand derivation):
#   SRC_DIR        repo source tree to scan
#   SHELLCHECK_BIN shellcheck executable
#
# A failure flag (not per-iteration exit) checks EVERY script and still fails
# the build if any failed — the previous bare loop only propagated the final
# iteration's status, silently swallowing mid-loop findings.
# LANG=C.UTF-8: the sandbox default (ASCII) makes shellcheck crash with
# "commitBuffer: invalid argument" when a finding excerpt contains unicode.
set -u
export LANG=C.UTF-8
cd "$SRC_DIR" || exit 1
status=0
while IFS= read -r -d "" script; do
  # Skip zsh scripts (shellcheck does not support them)
  if head -1 "$script" | grep -q "zsh"; then
    echo "Skipping zsh script: $script"
  else
    echo "Checking $script..."
    "$SHELLCHECK_BIN" --severity=warning --exclude=SC1091 "$script" || status=1
  fi
done < <(find . -name "*.sh" -not -path "./.git/*" -not -path "./result/*" -print0)
exit "$status"
