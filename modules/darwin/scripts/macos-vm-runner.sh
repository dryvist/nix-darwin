# shellcheck shell=bash
# Prepare the service user's Tart keychain and render sand's host-only App ID.

umask 077
app_id_file="${MACOS_VM_RUNNER_APP_ID_FILE:?}"
private_key_file="${MACOS_VM_RUNNER_PRIVATE_KEY_FILE:?}"
state_dir="${MACOS_VM_RUNNER_STATE_DIR:?}"
template="${MACOS_VM_RUNNER_SAND_TEMPLATE:?}"
security_bin=/usr/bin/security

# PathState watches the PEM. Hold quietly if the App ID has not been installed.
while :; do
  app_id=$(tr -d '[:space:]' < "$app_id_file" 2>/dev/null || true)
  if [[ $app_id =~ ^[0-9]+$ && -r $private_key_file && -s $private_key_file ]]; then
    break
  fi
  sleep 60
done

keychain_dir="$state_dir/Library/Keychains"
keychain="$keychain_dir/login.keychain-db"
mkdir -p "$keychain_dir"
chmod 0700 "$keychain_dir"
[[ -e $keychain ]] || "$security_bin" create-keychain -p "" "$keychain"
"$security_bin" unlock-keychain -p "" "$keychain"
"$security_bin" set-keychain-settings "$keychain"
"$security_bin" login-keychain -s "$keychain"

runtime_dir="$state_dir/run"
mkdir -p "$runtime_dir"
chmod 0700 "$runtime_dir"
sed "s/@APP_ID@/$app_id/" "$template" > "$runtime_dir/sand.yml"
exec sand run --config "$runtime_dir/sand.yml"
