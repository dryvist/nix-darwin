# shellcheck shell=bash
# macOS VM runner start script: the body of the runner LaunchDaemon.
#
# Runs as the hidden service account declared in
# modules/darwin/apps/macos-vm-runner.nix, with HOME set to its state directory
# and TART_HOME under it. In order:
#   1. make a login keychain, unlocked and without an auto-lock;
#   2. read the App ID and render the sand config from its template;
#   3. exec sand, which runs one ephemeral Tart VM per job.
#
# Keychain step. Tart's FAQ, "Headless machines" (https://tart.run/faq/): from
# macOS 15, Virtualization.framework needs an unlocked login.keychain, and
# without one a VM fails with "Interaction is not allowed with the Security
# Server". The FAQ's automated workaround is create-keychain, unlock-keychain
# and login-keychain -s, run as the account that starts the VM. This script is
# that account's start. The keychain uses an empty password, as the FAQ example
# does, so no generated secret is stored. The keychain holds nothing, so there
# is nothing for a password to protect. set-keychain-settings with no flags sets
# no timeout and no lock on sleep, so the keychain stays unlocked while the
# daemon runs.
#
# Every step logs one line. Re-running is safe: an existing keychain is reused
# and unlocked again.
#
# Environment (module-injected):
#   MACOS_VM_RUNNER_APP_ID_FILE    file holding the numeric App ID
#   MACOS_VM_RUNNER_STATE_DIR      the service account's home
#   MACOS_VM_RUNNER_SAND_TEMPLATE  sand config template containing @APP_ID@
#   MACOS_VM_RUNNER_SECURITY_BIN   security(1) path (default /usr/bin/security)

umask 077

log() { echo "macos-vm-runner: $*" >&2; }

app_id_file="${MACOS_VM_RUNNER_APP_ID_FILE:?MACOS_VM_RUNNER_APP_ID_FILE not set}"
state_dir="${MACOS_VM_RUNNER_STATE_DIR:?MACOS_VM_RUNNER_STATE_DIR not set}"
template="${MACOS_VM_RUNNER_SAND_TEMPLATE:?MACOS_VM_RUNNER_SAND_TEMPLATE not set}"
security_bin="${MACOS_VM_RUNNER_SECURITY_BIN:-/usr/bin/security}"

keychain_dir="$state_dir/Library/Keychains"
keychain="$keychain_dir/login.keychain-db"

mkdir -p "$keychain_dir"
chmod 0700 "$keychain_dir"

if [ -e "$keychain" ]; then
  log "keychain present: $keychain"
else
  if ! "$security_bin" create-keychain -p "" "$keychain"; then
    log "create-keychain failed for $keychain"
    exit 1
  fi
  log "created keychain $keychain"
fi

if ! "$security_bin" unlock-keychain -p "" "$keychain"; then
  log "unlock-keychain failed for $keychain"
  exit 1
fi
log "unlocked keychain $keychain"

if ! "$security_bin" set-keychain-settings "$keychain"; then
  log "set-keychain-settings failed for $keychain"
  exit 1
fi
log "keychain $keychain: no timeout, no lock on sleep"

if ! "$security_bin" login-keychain -s "$keychain"; then
  log "login-keychain -s failed for $keychain"
  exit 1
fi
log "login keychain is $keychain"

if ! app_id="$(tr -d '[:space:]' < "$app_id_file")"; then
  log "cannot read $app_id_file"
  exit 1
fi
if [[ ! $app_id =~ ^[0-9]+$ ]]; then
  log "$app_id_file must hold the numeric App ID"
  exit 1
fi

# Rendered config lives in the service account's state directory, never in the store.
runtime_dir="$state_dir/run"
mkdir -p "$runtime_dir"
chmod 0700 "$runtime_dir"
sed "s/@APP_ID@/$app_id/" "$template" > "$runtime_dir/sand.yml"
log "rendered sand config to $runtime_dir/sand.yml"

log "starting sand"
exec sand run --config "$runtime_dir/sand.yml"
