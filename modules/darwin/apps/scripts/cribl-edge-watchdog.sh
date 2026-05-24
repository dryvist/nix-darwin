#!/usr/bin/env bash
# Cribl Edge deadman heartbeat.
#
# Polled by launchd every 5 minutes. Sends a heartbeat ping to each
# configured Healthchecks endpoint *only* when the local Cribl Edge daemon
# is alive AND its log file has been written to in the last 5 minutes.
#
# When the daemon dies, wedges, or the Mac goes hard-down, the heartbeats
# stop and the upstream Healthchecks instance fires its alert.
#
# Arguments (set by the Nix wrapper in cribl-edge-watchdog.nix):
#   $1 = path to sops-rendered KEY=value file
#        (whitelisted keys: HEALTHCHECKS_IO_URL, HEALTHCHECKS_LOCAL_URL)
#   $2 = launchd label of the daemon to monitor
#   $3 = absolute path to the daemon's log file (used as the "is it doing
#        work?" liveness signal — recent mtime means cribl is awake)
#   $4 = mtime threshold in seconds (logs older than this -> daemon wedged)
#
# Exits 0 in every "deadman fires upstream" path so launchd does not retry
# this script — the deadman *should* fire when this script chose not to ping.

set -euo pipefail

SECRETS_FILE="${1:?secrets file path required}"
DAEMON_LABEL="${2:?launchd daemon label required}"
LOG_FILE="${3:?daemon log file path required}"
LOG_MTIME_THRESHOLD="${4:?log mtime threshold (seconds) required}"

HEALTHCHECKS_IO_URL=""
HEALTHCHECKS_LOCAL_URL=""

# Whitelist-only parse; ignores comments, blanks, and any unknown keys so a
# stale or tampered secrets file cannot inject shell.
if [ -r "$SECRETS_FILE" ]; then
  while IFS='=' read -r _k _v || [ -n "$_k" ]; do
    case "$_k" in
      ""|\#*) continue ;;
      HEALTHCHECKS_IO_URL)    HEALTHCHECKS_IO_URL="$_v" ;;
      HEALTHCHECKS_LOCAL_URL) HEALTHCHECKS_LOCAL_URL="$_v" ;;
    esac
  done < "$SECRETS_FILE"
fi

# No URLs configured -> nothing to ping. Exit cleanly; the upstream
# Healthchecks endpoints have not been armed yet, so this is not an error.
if [ -z "$HEALTHCHECKS_IO_URL" ] && [ -z "$HEALTHCHECKS_LOCAL_URL" ]; then
  exit 0
fi

# Liveness gate 1: launchd reports the daemon as running.
# Single `launchctl print` call — capture both exit status (daemon not
# bootstrapped) and stdout (daemon state) in one syscall.
if ! daemon_info=$(/bin/launchctl print "system/${DAEMON_LABEL}" 2>/dev/null); then
  exit 0
fi
if ! printf '%s\n' "$daemon_info" | /usr/bin/grep -q "state = running"; then
  exit 0
fi

# Liveness gate 2: the daemon's log file was touched recently.
# A pgrep-alive daemon that has stopped writing logs is wedged — treat as down.
if [ ! -f "$LOG_FILE" ]; then
  exit 0
fi
log_mtime=$(/usr/bin/stat -f %m "$LOG_FILE")
now=$(/bin/date +%s)
log_age=$((now - log_mtime))
if [ "$log_age" -gt "$LOG_MTIME_THRESHOLD" ]; then
  exit 0
fi

# Both gates passed — daemon is alive and doing work. Fan out the heartbeat.
# Non-fatal on individual failure: if healthchecks.io is unreachable but the
# self-hosted endpoint succeeds, we still want the latter to be marked alive.
# --max-time caps total time so a stuck endpoint can't block the second ping.
if [ -n "$HEALTHCHECKS_IO_URL" ]; then
  /usr/bin/curl -fsS --max-time 10 -o /dev/null "$HEALTHCHECKS_IO_URL" || true
fi
if [ -n "$HEALTHCHECKS_LOCAL_URL" ]; then
  /usr/bin/curl -fsS --max-time 10 -o /dev/null "$HEALTHCHECKS_LOCAL_URL" || true
fi
