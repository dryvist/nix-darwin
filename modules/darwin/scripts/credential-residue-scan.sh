#!/usr/bin/env bash
# Endpoint credential-residue scan.
#
# Looks for credential MATERIAL sitting loose in the directories where it
# accumulates by accident -- downloads, the desktop, temp space -- and reports
# what it finds. It exists because material of that kind was found twice in one
# afternoon, both times by hand, both times during work aimed at something
# else. Nothing was watching, so the only control was somebody happening to
# look.
#
# REPORTS, NEVER DELETES. That restriction is deliberate and load-bearing.
# Some credential material cannot be regenerated, so an automatic sweep can
# permanently destroy the only copy of a recovery path. A signing key can be
# reissued; a recovery share whose rotation endpoint does not exist cannot. The
# tool that cannot tell those apart must not be the tool that deletes.
#
# It also never prints a matched VALUE -- only the path, the category, the file
# mode and the age. A scanner that echoes what it finds turns one exposure into
# two, and its own log is usually the more durable of the two.
#
# Markers for alert rules:
#   clean:   "credential-residue-scan: clean (<n> paths scanned)"
#   finding: "credential-residue-scan: <n> finding(s)"
#
# Exit status: 0 clean, 1 findings, 2 self-check failed.

set -uo pipefail

SCAN_DIRS=${CREDENTIAL_RESIDUE_DIRS:-"$HOME/Downloads $HOME/Desktop"}
MAX_BYTES=${CREDENTIAL_RESIDUE_MAX_BYTES:-2000000}

log() {
  logger -t credential-residue-scan "$*" 2>/dev/null || true
  printf '%s\n' "credential-residue-scan: $*"
}

# Category patterns: deliberately GENERIC shapes -- a PEM header, a documented
# field name, a published key-id prefix. None is tuned to a value from this
# estate, which matters because this file is public. A pattern narrowed to
# match one specific secret discloses that secret to everyone who reads the
# pattern, which is the same mistake as pasting it.
CATEGORIES=(
  "private key material|-----BEGIN [A-Z ]*PRIVATE KEY-----"
  "recovery shares|recovery_keys_(b64|hex)"
  "cloud access key id|(AKIA|ASIA)[A-Z0-9]{16}"
)

scan_one() { # $1 = directory; echoes one line per finding
  local dir=$1 file label pattern mode days perm entry
  [ -d "$dir" ] || return 0
  while IFS= read -r -d '' file; do
    printf 'SCANNED\n'
    for entry in "${CATEGORIES[@]}"; do
      label=${entry%%|*}
      pattern=${entry#*|}
      if LC_ALL=C grep -qEa -- "$pattern" "$file" 2>/dev/null; then
        mode=$(stat -f '%Lp' "$file" 2>/dev/null || echo '???')
        days=$(( ( $(date +%s) - $(stat -f '%m' "$file" 2>/dev/null || date +%s) ) / 86400 ))
        perm=""
        # Any read bit for group or other on credential material is its own
        # finding, on top of where the file is sitting.
        case "$mode" in
          ??[4567]|?[4567]?|?[4567][4567]) perm=" READABLE-BY-OTHERS" ;;
        esac
        printf 'FINDING\t%s\t%s\t%s\t%s\t%s\n' "$label" "$file" "$mode" "$days" "$perm"
        break
      fi
    done
  done < <(find "$dir" -type f -size -"${MAX_BYTES}"c -print0 2>/dev/null)
}

# A scan reporting "clean" is indistinguishable from a scan whose patterns
# stopped matching. Prove the scanner still sees a known-bad file before
# trusting a clean result -- the control needs its own control.
selftest() {
  local tmp rc
  tmp=$(mktemp -d) || return 1
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nnotarealkey\n' > "$tmp/fixture.pem"
  rc=0
  scan_one "$tmp" | grep -q '^FINDING' || rc=1
  rm -rf "$tmp"
  return $rc
}

if ! selftest; then
  log "SELF-CHECK FAILED: the scanner did not match a known-bad fixture."
  log "Treat any clean result as meaningless until this is fixed."
  exit 2
fi

findings=0
scanned=0
while IFS= read -r line; do
  case "$line" in
    SCANNED) scanned=$((scanned + 1)) ;;
    FINDING*)
      IFS=$'\t' read -r _ label file mode days perm <<<"$line"
      log "FINDING ${label}: ${file} mode=${mode} age=${days}d${perm}"
      findings=$((findings + 1))
      ;;
  esac
done < <(for d in $SCAN_DIRS; do scan_one "$d"; done)

if [ "$findings" -eq 0 ]; then
  log "clean (${scanned} paths scanned)"
  exit 0
fi

log "${findings} finding(s)"
log "Reported, not removed. Confirm another copy exists BEFORE deleting any of"
log "these: for material that cannot be reissued, deleting it is the loss."
exit 1
