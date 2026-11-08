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

@test "a path outside the store removes nothing" {
  run bash "$SCRIPT_UNDER_TEST" "$BATS_TEST_TMPDIR/uv/bin/caddy"

  [ "$status" -eq 0 ]
  ! grep -q -- '--remove' "$ALF_CALL_LOG"
  grep -Fqx -- "--add $BATS_TEST_TMPDIR/uv/bin/caddy" "$ALF_CALL_LOG"
}

@test "cluster-alf-allow passes every uv interpreter to alf-allow-apps" {
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/share/uv/python/cpython-3.14-macos/bin"
  for name in python3 python3.14; do
    : >"$BATS_TEST_TMPDIR/home/.local/share/uv/python/cpython-3.14-macos/bin/$name"
    chmod +x "$BATS_TEST_TMPDIR/home/.local/share/uv/python/cpython-3.14-macos/bin/$name"
  done
  printf '#!%s\nprintf "%%s\\n" "$@" >>"$ALF_CALL_LOG"\n' "$BASH" >"$BATS_TEST_TMPDIR/alf-allow-apps"
  chmod +x "$BATS_TEST_TMPDIR/alf-allow-apps"

  export CLUSTER_USER_HOME="$BATS_TEST_TMPDIR/home" ALF_ALLOW_APPS="$BATS_TEST_TMPDIR/alf-allow-apps"
  run bash "$BATS_TEST_DIRNAME/../../modules/darwin/scripts/cluster-alf-allow.sh"

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$ALF_CALL_LOG")" -eq 2 ]
  grep -q '/bin/python3.14$' "$ALF_CALL_LOG"
}

@test "a failed removal is reported as not removed" {
  printf '#!%s\n[ "$1" = --listapps ] && cat "$ALF_LISTAPPS"\n[ "$1" != --remove ]\n' "$BASH" >"$ALF_SOCKETFILTERFW"

  run bash "$SCRIPT_UNDER_TEST" "$CURRENT"

  [ "$status" -eq 0 ]
  [[ $output == *"could not remove stale $STALE"* ]]
  [[ $output != *"removed stale $STALE"* ]]
}

@test "a failing firewall call does not stop the remaining apps" {
  printf '#!%s\nprintf "%%s\\n" "$*" >>"$ALF_CALL_LOG"\nexit 1\n' "$BASH" >"$ALF_SOCKETFILTERFW"

  run bash "$SCRIPT_UNDER_TEST" "$CURRENT" "$OTHER"

  [ "$status" -eq 0 ]
  grep -Fqx -- "--unblockapp $OTHER" "$ALF_CALL_LOG"
}
