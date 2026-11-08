#!/usr/bin/env bats

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../../modules/darwin/scripts/alf-allow-apps.sh"
CURRENT=/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-caddy-2.11.7/bin/caddy
STALE=/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-caddy-2.11.4/bin/caddy
OTHER=/nix/store/cccccccccccccccccccccccccccccccc-macmon-0.10.0/bin/macmon

setup() {
  export ALF_SOCKETFILTERFW="$BATS_TEST_TMPDIR/socketfilterfw"
  export ALF_CALL_LOG="$BATS_TEST_TMPDIR/calls"
  export ALF_LISTAPPS="$BATS_TEST_TMPDIR/listapps"
  : >"$ALF_CALL_LOG"
  printf '#!%s\n' "$BASH" >"$ALF_SOCKETFILTERFW"
  cat >>"$ALF_SOCKETFILTERFW" <<'STUB'
if [ "$1" = --listapps ]; then
  cat "$ALF_LISTAPPS"
else
  printf '%s\n' "$*" >>"$ALF_CALL_LOG"
fi
STUB
  chmod +x "$ALF_SOCKETFILTERFW"
  cat >"$ALF_LISTAPPS" <<EOF
ALF: total number of apps = 4

1 : /usr/bin/nc
 	 (Allow incoming connections)

2 : $STALE
 	 (Allow incoming connections)

3 : $OTHER
 	 (Allow incoming connections)

4 : $CURRENT
 	 (Allow incoming connections)
EOF
}

@test "removes the stale entry with the same name, then allows the current path" {
  run bash "$SCRIPT_UNDER_TEST" "$CURRENT"

  [ "$status" -eq 0 ]
  [ "$(cat "$ALF_CALL_LOG")" = "--remove $STALE
--add $CURRENT
--unblockapp $CURRENT" ]
  [[ "$output" == *"removed stale $STALE"* ]]
}

@test "keeps entries with other names and entries that are allowed" {
  run bash "$SCRIPT_UNDER_TEST" "$CURRENT" "$STALE" "$OTHER"

  [ "$status" -eq 0 ]
  ! grep -q -- '--remove' "$ALF_CALL_LOG"
  [ "$(grep -c -- '--add' "$ALF_CALL_LOG")" -eq 3 ]
}

@test "a failing firewall call does not stop the remaining apps" {
  printf '#!%s\nprintf "%%s\\n" "$*" >>"$ALF_CALL_LOG"\nexit 1\n' "$BASH" >"$ALF_SOCKETFILTERFW"

  run bash "$SCRIPT_UNDER_TEST" "$CURRENT" "$OTHER"

  [ "$status" -eq 0 ]
  grep -Fqx -- "--unblockapp $OTHER" "$ALF_CALL_LOG"
}
