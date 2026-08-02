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

# `lowpowermode` and `powermode` are two names for ONE preference slot, not two
# keys: writing either changes the same value, and `pmset -g custom` prints
# whichever name the model exposes (never both). So this write and the Energy
# Mode block below would fight over the same slot, last-writer-wins. Energy Mode
# is the more expressive of the two (it can ask for High, which the boolean
# cannot), so it owns the slot whenever it is managed and the boolean stands
# down. Without this, `lowPowerMode = false` would silently mean "Automatic"
# and quietly cancel a High Power request on every activation.
if [ -n "${ENERGY_MODE_DESIRED:-}" ] && [ "${ENERGY_MODE_DESIRED}" != "unmanaged" ]; then
  [ -z "${PMSET_LOWPOWERMODE:-}" ] ||
    log "pmset lowpowermode skipped: Energy Mode (${ENERGY_MODE_DESIRED}) owns this slot"
else
  apply_pmset lowpowermode "${PMSET_LOWPOWERMODE:-}"
fi
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
# MAPPING — 0 = Automatic, 1 = Low Power, 2 = High Power.
#
# This is the legacy `lowpowermode` boolean widened in place, which is what pins
# the low two values: `lowpowermode 0` (off) and `lowpowermode 1` (on) had to
# keep meaning what they always did, so High Power could only be bolted on as
# the new 2. An earlier revision of this script asserted "1 = High Power" and
# therefore drove every managed Mac into Low Power Mode on each activation —
# the exact opposite of the intent, and invisible except as slow tokens. Do not
# "correct" these constants without reading back the System Settings UI first.
#
# Which NAME the slot goes by varies by model, so resolve it before writing:
# models with the tri-state control report `powermode`, older/desktop models
# report the `lowpowermode` boolean, and a model with no Energy Mode control at
# all reports neither — there the set is skipped rather than retried forever.
# Whichever name is reported is the one that must be written; writing the other
# is silently accepted but never shows up in `pmset -g custom`.
pm_key=""
read_powermode() {
  # $1 = "AC" or "Battery"; prints that block's value for $pm_key, empty if absent.
  /usr/bin/pmset -g custom 2>/dev/null | /usr/bin/awk \
    -v want_block="$1 Power:" -v key="${pm_key}" '
    index($0, want_block) == 1 { in_block = 1; next }
    /Power:[[:space:]]*$/ { in_block = 0 }
    in_block && $1 == key { print $2; exit }
  ' || true
}

if [ -n "${ENERGY_MODE_DESIRED:-}" ] && [ "${ENERGY_MODE_DESIRED}" != "unmanaged" ]; then
  for candidate in powermode lowpowermode; do
    pm_key="${candidate}"
    [ -z "$(read_powermode AC)" ] || break
    pm_key=""
  done

  case "${ENERGY_MODE_DESIRED}" in
    # ac_want / batt_want. High Power is an AC-only mode on portables: macOS
    # offers no High on battery, so the closest non-throttled request there is
    # Automatic. Asking for 2 on the battery block is what makes a `-a` write
    # fail as a unit, which is why the two sources are written separately.
    high) ac_want=2 batt_want=0 ;;
    automatic) ac_want=0 batt_want=0 ;;
    low) ac_want=1 batt_want=1 ;;
    *) ac_want="" batt_want="" ;;
  esac

  # A boolean-only model has no High Power to offer, so "high" degrades to the
  # best it can do — 0, the boolean's off/unthrottled state. Clamping here (not
  # at the write) keeps the verify re-read comparing against what was asked for.
  if [ "${pm_key}" = "lowpowermode" ] && [ "${ac_want}" = "2" ]; then
    log "Energy Mode: model exposes only lowpowermode (no High Power); requesting unthrottled (0)"
    ac_want=0
  fi

  if [ -z "${ac_want}" ]; then
    warn "Energy Mode: unrecognised desired value '${ENERGY_MODE_DESIRED}'; leaving power mode untouched"
  elif [ -z "${pm_key}" ]; then
    warn "Energy Mode: no powermode/lowpowermode key reported (model exposes no Energy Mode control); skipping"
  else
    for src in AC Battery; do
      case "${src}" in
        AC) flag="-c" want="${ac_want}" ;;
        *) flag="-b" want="${batt_want}" ;;
      esac
      before="$(read_powermode "${src}")"
      # A desktop reports no Battery block at all — nothing to set there.
      if [ -z "${before}" ]; then
        log "Energy Mode: no ${src} ${pm_key} block on this model; skipping"
        continue
      fi
      if [ "${before}" = "${want}" ]; then
        log "Energy Mode ${src} ${pm_key}=${before} already matches ${ENERGY_MODE_DESIRED}"
        continue
      fi
      # Apply, then re-read. Never trust the exit code alone: pmset can accept a
      # value the hardware then ignores, which would report success while the
      # machine stays throttled.
      if ! /usr/bin/pmset "${flag}" "${pm_key}" "${want}" 2>/dev/null; then
        warn "Energy Mode: pmset ${flag} ${pm_key} ${want} (${src}) failed; set it in System Settings -> Battery -> Energy Mode"
        continue
      fi
      now="$(read_powermode "${src}")"
      if [ "${now}" = "${want}" ]; then
        log "Energy Mode set: ${src} ${pm_key} ${before} -> ${now} (${ENERGY_MODE_DESIRED})"
      else
        warn "Energy Mode: pmset accepted ${src} ${pm_key}=${want} but it read back as '${now:-empty}'; set it in System Settings -> Battery -> Energy Mode"
      fi
    done

    # Backstop, deliberately independent of every branch above: whatever path
    # was taken, a host asking for anything other than Low must not be sitting
    # in Low Power Mode when this returns. This is the check that would have
    # caught the inverted mapping on its first activation.
    if [ "${ENERGY_MODE_DESIRED}" != "low" ]; then
      for src in AC Battery; do
        [ "$(read_powermode "${src}")" = "1" ] || continue
        warn "Energy Mode: ${src} is in LOW POWER MODE despite energyMode=${ENERGY_MODE_DESIRED} — throttled; fix System Settings -> Battery -> Energy Mode"
      done
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
