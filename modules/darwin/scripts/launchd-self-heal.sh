#!/usr/bin/env bash
# Self-heal critical KeepAlive LaunchDaemons after every activation.
#
# Args: one LaunchDaemon label per positional argument (e.g.
# com.nix-darwin.cribl-edge). See modules/darwin/launchd-self-heal.nix for
# the option that feeds this script and the full rationale.
#
# No `set -e`: every failure here must be a non-fatal warning so the
# critical /run/current-system symlink update (which runs after this) is
# never blocked. See docs/ACTIVATION-SCRIPTS-RULES.md.
set -uo pipefail

is_running() {
  /bin/launchctl print "system/$1" 2>/dev/null | grep -qE '^[[:space:]]*pid = [0-9]+[[:space:]]*$'
}

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] launchd self-heal: checking $# critical daemon(s)..."
for label in "$@"; do
  plist="/Library/LaunchDaemons/$label.plist"
  if [ ! -f "$plist" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] launchd self-heal: $label plist missing, skipping" >&2
    continue
  fi

  if is_running "$label"; then
    continue
  fi

  # Not running. Force a clean reload. NEVER `launchctl kickstart` here — it
  # HANGS forever on a penalty-boxed daemon. bootout clears the wedged state;
  # bootstrap starts it fresh (RunAtLoad). bootout is allowed to fail (daemon
  # may be fully absent), hence `|| true`.
  #
  # A single reload isn't proof of life: if the daemon's cause of death is
  # still present (e.g. a genuinely broken config, not just a wedged launchd
  # state), the fresh spawn crashes again immediately and relapses into the
  # penalty box with nothing to notice. So re-check after each attempt and
  # retry once more with a longer wait before giving up loudly.
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] launchd self-heal: $label not running; reloading (bootout+bootstrap)" >&2
  healed=0
  for wait_secs in 5 15; do
    /bin/launchctl bootout "system/$label" 2>/dev/null || true
    /bin/launchctl bootstrap system "$plist" || true
    sleep "$wait_secs"
    if is_running "$label"; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] launchd self-heal: $label reloaded and running" >&2
      healed=1
      break
    fi
  done
  if [ "$healed" -ne 1 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] launchd self-heal: $label still not running after reload retries — needs manual investigation" >&2
  fi
done
