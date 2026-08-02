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

apply_pmset lowpowermode "${PMSET_LOWPOWERMODE:-}"
apply_pmset powernap "${PMSET_POWERNAP:-}"
apply_pmset proximitywake "${PMSET_PROXIMITYWAKE:-}"
apply_pmset disablesleep "${PMSET_DISABLESLEEP:-}"
apply_pmset tcpkeepalive "${PMSET_TCPKEEPALIVE:-}"

# --- High Power Mode (Energy Mode) enforce -------------------------------
# SET it, then verify by re-reading. This used to only warn, on the belief
# that Energy Mode "cannot be set via CLI" — `pmset -a powermode <n>` does
# work as root on models that expose it, and this script already runs as root
# at activation. A cluster rank left on Automatic thermally throttles mid-run,
# which shows up as inexplicably slow tokens rather than as an error, so a
# warning nobody reads was the wrong control.
#
# Read the AC-block powermode from `pmset -g custom`. Observed mapping:
# 0 = Automatic, 1 = High Power, 2 = Low Power. Models that do not expose it
# (e.g. desktops without an Energy Mode control) report empty — there the set
# is skipped rather than retried every activation.
if [ -n "${ENERGY_MODE_DESIRED:-}" ] && [ "${ENERGY_MODE_DESIRED}" != "unmanaged" ]; then
  ac_powermode="$(/usr/bin/pmset -g custom 2>/dev/null | /usr/bin/awk '
    /^AC Power:/ { in_ac = 1; next }
    /Power:[[:space:]]*$/ { in_ac = 0 }
    in_ac && $1 == "powermode" { print $2; exit }
  ' || true)"
  case "${ENERGY_MODE_DESIRED}" in
    high) want=1 ;;
    automatic) want=0 ;;
    low) want=2 ;;
    *) want="" ;;
  esac
  if [ -z "${ac_powermode}" ]; then
    warn "Energy Mode: AC powermode not reported (model does not expose it); skipping"
  elif [ -z "${want}" ]; then
    warn "Energy Mode: unrecognised desired value '${ENERGY_MODE_DESIRED}'; leaving powermode=${ac_powermode}"
  elif [ "${ac_powermode}" = "${want}" ]; then
    log "Energy Mode AC powermode=${ac_powermode} already matches desired ${ENERGY_MODE_DESIRED}"
  else
    # Apply, then re-read. Never trust the exit code alone: pmset can accept a
    # value the hardware then ignores, which would report success while the
    # machine stays on Automatic.
    if /usr/bin/pmset -a powermode "${want}" 2>/dev/null; then
      ac_now="$(/usr/bin/pmset -g custom 2>/dev/null | /usr/bin/awk '
        /^AC Power:/ { in_ac = 1; next }
        /Power:[[:space:]]*$/ { in_ac = 0 }
        in_ac && $1 == "powermode" { print $2; exit }
      ' || true)"
      if [ "${ac_now}" = "${want}" ]; then
        log "Energy Mode set: AC powermode ${ac_powermode} -> ${ac_now} (${ENERGY_MODE_DESIRED})"
      else
        warn "Energy Mode: pmset accepted powermode=${want} but it read back as '${ac_now:-empty}'; set it in System Settings -> Battery -> Energy Mode"
      fi
    else
      warn "Energy Mode: pmset -a powermode ${want} failed; set it in System Settings -> Battery -> Energy Mode"
    fi
  fi
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
