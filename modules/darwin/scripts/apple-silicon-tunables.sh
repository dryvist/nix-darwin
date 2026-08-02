#!/usr/bin/env bash
#
# Apple Silicon System Tunables — runtime apply (activation only)
#
# Reads tunables from environment variables passed by the nix-darwin
# activation script. Each step is best-effort: a failure logs a warning but
# does not abort the rest. Native macOS CLIs only — no third-party deps.
#
# Volatile iogpu/vm sysctls live in apple-silicon-sysctls.sh (so they can also
# re-apply at boot). This script holds the persistent and verify-only knobs:
# pmset perf flags, Energy Mode verify, Spotlight, Time Machine, App Nap, and
# the Metal debug-env guard.

prefix="[apple-silicon-tunables]"
log() { echo "$prefix INFO $*"; }
warn() { echo "$prefix WARN $*" >&2; }

# --- pmset performance flags ---------------------------------------------
# "0"/"1" to set on all power sources, or empty to leave the default.
apply_pmset() {
  local flag="$1" value="$2"
  [ -n "${value}" ] || return 0
  if /usr/bin/pmset -a "${flag}" "${value}" >/dev/null 2>&1; then
    log "pmset -a ${flag} ${value}"
  else
    warn "pmset -a ${flag} ${value} failed"
  fi
}

apply_pmset powernap "${PMSET_POWERNAP:-}"
apply_pmset proximitywake "${PMSET_PROXIMITYWAKE:-}"
apply_pmset disablesleep "${PMSET_DISABLESLEEP:-}"
apply_pmset tcpkeepalive "${PMSET_TCPKEEPALIVE:-}"

# --- High Power Mode (Energy Mode) enforce -------------------------------
# `powermode` is a THREE-state control and its values follow the System
# Settings -> Battery -> Energy Mode menu order:
#
#   0 = Automatic    1 = Low Power    2 = High Power
#
# High Power is the only value this repo ever writes. Automatic thermally
# throttles a rank mid-run, which surfaces as inexplicably slow tokens rather
# than as an error; Low Power does the same, harder.
#
# `pmset -a lowpowermode <0|1>` writes this same key, so a boolean can only
# ever reach Automatic or Low Power — never High. That is why it is not used
# here and why no `lowPowerMode` option exists.
#
# Both power sources are checked. Enforcing AC alone leaves a laptop that
# throttles the moment it is unplugged, which is exactly when a long run is
# least able to report why it slowed down.
#
# Models that do not expose an Energy Mode control report empty — there the
# set is skipped rather than retried every activation.
POWERMODE_HIGH=2

read_powermode() {
  # $1 = "AC" or "Battery"
  /usr/bin/pmset -g custom 2>/dev/null | /usr/bin/awk -v want_block="$1 Power:" '
    $0 == want_block { in_block = 1; next }
    /Power:[[:space:]]*$/ { in_block = 0 }
    in_block && $1 == "powermode" { print $2; exit }
  ' || true
}

if [ "${ENERGY_MODE_DESIRED:-high}" != "unmanaged" ]; then
  for source in AC Battery; do
    current="$(read_powermode "${source}")"
    if [ -z "${current}" ]; then
      log "Energy Mode: ${source} powermode not reported (model does not expose it); skipping"
      continue
    fi
    if [ "${current}" = "${POWERMODE_HIGH}" ]; then
      log "Energy Mode: ${source} powermode=${current} (High Power)"
      continue
    fi
    # Apply, then re-read. Never trust the exit code alone: pmset can accept a
    # value the hardware then ignores, which would report success while the
    # machine stays throttled.
    /usr/bin/pmset -a powermode "${POWERMODE_HIGH}" 2>/dev/null || true
    now="$(read_powermode "${source}")"
    if [ "${now}" = "${POWERMODE_HIGH}" ]; then
      log "Energy Mode: ${source} powermode ${current} -> ${now} (High Power)"
    else
      warn "Energy Mode: ${source} powermode is '${now:-empty}', not High Power (${POWERMODE_HIGH}) — the machine will throttle. Set System Settings -> Battery -> Energy Mode -> High Power"
    fi
  done
fi

# --- Spotlight indexing off on the HuggingFace volume --------------------
# Every model download otherwise re-indexes hundreds of GB.
if [ -d "${HF_VOLUME:-}" ]; then
  if /usr/bin/mdutil -i off "${HF_VOLUME}" >/dev/null 2>&1; then
    log "mdutil indexing disabled on ${HF_VOLUME}"
  else
    warn "mdutil -i off ${HF_VOLUME} failed"
  fi
else
  warn "HF volume ${HF_VOLUME:-} is missing or not mounted; skipping mdutil -i off"
fi

# --- Time Machine excludes for the AI cache directories ------------------
# TM_EXCLUDES is a colon-separated list of absolute paths.
if [ -n "${TM_EXCLUDES:-}" ]; then
  IFS=':' read -ra _excludes <<<"${TM_EXCLUDES}"
  for _path in "${_excludes[@]}"; do
    if [ -e "${_path}" ]; then
      if /usr/bin/tmutil addexclusion "${_path}" >/dev/null 2>&1; then
        log "tmutil exclude ${_path}"
      else
        warn "tmutil addexclusion ${_path} failed"
      fi
    else
      warn "tmutil exclusion skipped for missing path ${_path}; rerun activation after it is created"
    fi
  done
fi

# --- App Nap off for inference daemons -----------------------------------
# Bundle IDs come in colon-separated. Defaults are per-user, so shell out as
# the configured user.
if [ -n "${APPNAP_BUNDLES:-}" ] && [ -n "${USER_NAME:-}" ]; then
  IFS=':' read -ra _bundles <<<"${APPNAP_BUNDLES}"
  for _bundle in "${_bundles[@]}"; do
    if /usr/bin/sudo -u "${USER_NAME}" /usr/bin/defaults write \
      "${_bundle}" NSAppSleepDisabled -bool YES >/dev/null 2>&1; then
      log "NSAppSleepDisabled=YES for ${_bundle}"
    else
      warn "defaults write ${_bundle} NSAppSleepDisabled failed"
    fi
  done
fi

# --- Metal debug/validation env vars: ensure unset -----------------------
# Any MTL_* validation/debug var silently taxes every inference. Check the
# launchd user context, warn if set, and clear it. METAL_UNSET_VARS is a
# colon-separated list. Canonical fix: the inference LaunchAgent (nix-ai
# programs.mlx) must never export them.
if [ -n "${METAL_UNSET_VARS:-}" ] && [ -n "${USER_NAME:-}" ]; then
  uid="$(/usr/bin/id -u "${USER_NAME}" 2>/dev/null || true)"
  IFS=':' read -ra _mtl <<<"${METAL_UNSET_VARS}"
  for _var in "${_mtl[@]}"; do
    if [ -n "${uid}" ]; then
      current="$(/bin/launchctl asuser "${uid}" /bin/launchctl getenv "${_var}" 2>/dev/null || true)"
    else
      current="$(/bin/launchctl getenv "${_var}" 2>/dev/null || true)"
    fi
    if [ -n "${current}" ]; then
      warn "Metal debug var ${_var}='${current}' set in launchd; clearing (canonical fix: do not export it in nix-ai programs.mlx)"
      if [ -n "${uid}" ]; then
        /bin/launchctl asuser "${uid}" /bin/launchctl unsetenv "${_var}" >/dev/null 2>&1 || true
      else
        /bin/launchctl unsetenv "${_var}" >/dev/null 2>&1 || true
      fi
    else
      log "Metal debug var ${_var} not set"
    fi
  done
fi

exit 0
