# Shared setup for the pf-hardening bats suites: a stub pfctl, logger and lsof, and the script
# under test assembled as the module does (lib prepended, writeShellApplication's options first).

SCRIPTS="$BATS_TEST_DIRNAME/../../modules/darwin/scripts"

# assemble <name>: writes $BATS_TEST_TMPDIR/<name>.sh and prints its path.
assemble() {
  local out="$BATS_TEST_TMPDIR/$1.sh"
  { echo "set -o errexit -o nounset -o pipefail"; cat "$SCRIPTS/pf-hardening-lib.sh" "$SCRIPTS/$1.sh"; } >"$out"
  echo "$out"
}

pf_stub_setup() {
  export PF_HARDENING_PFCTL="$BATS_TEST_TMPDIR/pfctl"
  export PF_HARDENING_LOGGER="$BATS_TEST_TMPDIR/logger"
  export PF_HARDENING_LSOF="$BATS_TEST_TMPDIR/lsof"
  export PF_HARDENING_LOCKF="$BATS_TEST_TMPDIR/lockf"
  export PF_HARDENING_LOG="$BATS_TEST_TMPDIR/pf-hardening.log"
  export PF_HARDENING_NOW=1800000000
  export PF_CALL_LOG="$BATS_TEST_TMPDIR/calls"
  # Present while com.apple/nix-hardening holds rules; a flush of that name removes it.
  export PF_ENFORCED_RULES="$BATS_TEST_TMPDIR/enforced-rules"
  : >"$PF_CALL_LOG"
  printf '#!%s\n' "$BASH" >"$PF_HARDENING_PFCTL"
  cat >>"$PF_HARDENING_PFCTL" <<'STUB'
printf 'pfctl %s\n' "$*" >>"$PF_CALL_LOG"
case "$*" in
  *" -f "*)
    if [ -n "${PF_TRIAL_DEADLINE_FILE:-}" ] && [ -f "$PF_TRIAL_DEADLINE_FILE" ]; then
      printf 'probe deadline-at-load %s\n' "$(cat "$PF_TRIAL_DEADLINE_FILE")" >>"$PF_CALL_LOG"
    fi
    [ -z "${PF_FAIL_LOAD:-}" ] || { echo "no IP address found for example.invalid" >&2; exit 1; } ;;
  "-a com.apple/nix-hardening -F rules") [ -n "${PF_FLUSH_STUCK:-}" ] || rm -f "$PF_ENFORCED_RULES" ;;
  *"-s rules")
    [ -z "${PF_RULES_QUERY_FAILS:-}" ] || { echo "DIOCGETRULES: Invalid argument" >&2; exit 1; }
    [ -z "${PF_STALE_RULES:-}" ] || echo "block drop in all"
    if [ "$2" = com.apple/nix-hardening ] && [ -f "$PF_ENFORCED_RULES" ]; then echo "block drop in all"; fi
    if [ -n "${PF_MANY_RULES:-}" ]; then seq 1 500 | sed 's/^/pass in rule /'; fi ;;
  *"-s Anchors")
    [ -z "${PF_ANCHORS_FAIL:-}" ] || exit 1
    printf '  %s\n' ${PF_LISTED_ANCHORS:-com.apple} ;;
  "-e") echo "pf already enabled" >&2; exit 1 ;;
  "-s info")
    [ -n "${PF_DISABLED:-}" ] && echo "Status: Disabled" || echo "Status: Enabled for 0 days 00:01:00"
    echo "  current entries                        3" ;;
esac
STUB
  printf '#!%s\nprintf "logger %%s\\n" "$*" >>"$PF_CALL_LOG"\n' "$BASH" >"$PF_HARDENING_LOGGER"
  printf '#!%s\nprintf "lsof %%s\\n" "$*" >>"$PF_CALL_LOG"\necho "sshd 1 root 4u IPv4 TCP *:22 (LISTEN)"\n' "$BASH" >"$PF_HARDENING_LSOF"
  # Single-run load cases need the lockf re-exec, not contention. The concurrency test
  # overrides this fake.
  printf '#!%s\n[ "$1" = "-k" ] || exit 2\nshift 2\nexec "$@"\n' "$BASH" >"$PF_HARDENING_LOCKF"
  chmod +x "$PF_HARDENING_PFCTL" "$PF_HARDENING_LOGGER" "$PF_HARDENING_LSOF" "$PF_HARDENING_LOCKF"
}
