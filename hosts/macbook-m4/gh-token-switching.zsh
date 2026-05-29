# GitHub token context switching — principle of least privilege
# Tokens are tiered PATs stored in macOS Keychain.
# Restricted: automation.keychain-db (unrestricted, AI can access freely)
# Elevated (private/dryvist/admin/org-admin): elevate-access.keychain-db
#   (password-protected, requires user unlock)
# Usage: gh-restricted | gh-private | gh-dryvist | gh-admin | gh-org-admin | gh-token-status
#
# REQUIRES (set by caller in home.nix initContent):
#   _KC_AI_ACCOUNT        keychain account name (e.g. ai-cli-coder)
#   _GH_SVC_RESTRICTED, _GH_DB_RESTRICTED
#   _GH_SVC_PRIVATE,    _GH_DB_PRIVATE
#   _GH_SVC_DRYVIST,    _GH_DB_DRYVIST
#   _GH_SVC_ADMIN,      _GH_DB_ADMIN
#   _GH_SVC_ORG_ADMIN,  _GH_DB_ORG_ADMIN

_gh_switch_token() {
  local svc="$1" db="$2" mode="$3" desc="$4"
  local output rc

  # Call `security` directly (not via _get_keychain_secret, which swallows
  # errors) so we can distinguish missing entries from other failures like
  # locked keychain, access denied, or user-interaction-not-allowed.
  # NOTE: `rc` not `status` — in zsh, $status is a read-only special parameter
  # (alias for $?). `local status` does not shadow it cleanly in zsh 5.9, and
  # the subsequent assignment raises "read-only variable: status" at runtime.
  output=$(security find-generic-password -w -s "$svc" -a "$_KC_AI_ACCOUNT" "$db" 2>&1)
  rc=$?

  if (( rc != 0 )); then
    if [[ "$output" == *"could not be found"* ]]; then
      echo "ERROR: No keychain entry for service '$svc' in '$db'" >&2
      echo "Add it:  security add-generic-password -U -s '$svc' -a '$_KC_AI_ACCOUNT' -w '<token>' '$db'" >&2
    else
      echo "ERROR: Failed to read keychain entry for service '$svc' in '$db'" >&2
      echo "$output" >&2
    fi
    return 1
  fi

  if [[ -z "$output" ]]; then
    echo "ERROR: Empty token returned for service '$svc' in '$db'" >&2
    return 1
  fi

  export GITHUB_TOKEN="$output"
  export GH_ENV_MODE="$mode"
  echo "GitHub context: $mode ($desc)"
}

gh-restricted() {
  _gh_switch_token "$_GH_SVC_RESTRICTED" "$_GH_DB_RESTRICTED" "RESTRICTED" "public repos"
}

gh-private() {
  _gh_switch_token "$_GH_SVC_PRIVATE" "$_GH_DB_PRIVATE" "PRIVATE" "+ JacobPEvans-personal private repos"
}

gh-dryvist() {
  _gh_switch_token "$_GH_SVC_DRYVIST" "$_GH_DB_DRYVIST" "DRYVIST" "+ dryvist org repos (public + private)"
}

gh-admin() {
  _gh_switch_token "$_GH_SVC_ADMIN" "$_GH_DB_ADMIN" "ADMIN" "JacobPEvans-personal admin"
}

gh-org-admin() {
  _gh_switch_token "$_GH_SVC_ORG_ADMIN" "$_GH_DB_ORG_ADMIN" "ORG_ADMIN" "dryvist org admin"
}

gh-token-status() {
  echo "GH_ENV_MODE=${GH_ENV_MODE:-unset}"
  if [[ -n "$GITHUB_TOKEN" ]]; then
    echo "GITHUB_TOKEN=set (${#GITHUB_TOKEN} chars)"
  else
    echo "GITHUB_TOKEN=unset"
  fi
}
