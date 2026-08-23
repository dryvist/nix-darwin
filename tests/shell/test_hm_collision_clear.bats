#!/usr/bin/env bats
# Behavioral tests for the pre-checkLinkTargets stray-symlink sweep.
#
# The scenario that matters: an unmanaged symlink at a home-manager-managed
# path. Upstream's collision check gates both of its backup branches on
# `! -L`, so such a link aborts activation before any file is written and no
# `backupCommand` / `backupFileExtension` setting can rescue it.

MODULE_UNDER_TEST="$BATS_TEST_DIRNAME/../../hosts/common/hm-collision-clear.nix"

# The sweep is inlined into the module (no standalone .sh file — see the
# module for why). `nix flake check` (lib/checks.nix) extracts the text at
# ordinary evaluation time and hands it in as HM_COLLISION_CLEAR_SWEEP,
# because the sandboxed check derivation has no `nix` binary and no
# recursive-nix to run `nix eval` itself. Outside that sandbox — a developer
# running this file directly — the variable is unset, so fall back to
# `nix eval` here. `lib.hm.dag.entryBefore` is the only `lib` function the
# module calls; a stand-in that returns its `text` argument unwrapped is
# enough to evaluate it standalone.
setup_file() {
  if [ -n "${HM_COLLISION_CLEAR_SWEEP:-}" ]; then
    SWEEP_SCRIPT="$HM_COLLISION_CLEAR_SWEEP"
  else
    SWEEP_SCRIPT="$(nix eval --impure --raw --expr \
      "(import \"$MODULE_UNDER_TEST\" { lib.hm.dag.entryBefore = _: text: text; }).home.activation.clearStrayLinkTargets")"
  fi
  export SWEEP_SCRIPT
}

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  newGenPath="$BATS_TEST_TMPDIR/gen"
  export newGenPath
  export DRY_RUN_CMD=""

  # home-files is a symlink to the generation's files directory, as it is in a
  # real generation — the sweep resolves it with a single readlink.
  mkdir -p "$HOME/.local/bin" "$BATS_TEST_TMPDIR/files/.local/bin" "$newGenPath"
  printf 'managed\n' >"$BATS_TEST_TMPDIR/files/.local/bin/agent"
  ln -s "$BATS_TEST_TMPDIR/files" "$newGenPath/home-files"
}

run_sweep() {
  run bash -c "$SWEEP_SCRIPT"
}

@test "an unmanaged symlink at a managed path is removed and logged" {
  ln -s /somewhere/else/cursor-agent "$HOME/.local/bin/agent"

  run_sweep
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.local/bin/agent" ]
  [ ! -L "$HOME/.local/bin/agent" ]
  [[ "$output" == *"clearing unmanaged symlink"* ]]
  [[ "$output" == *".local/bin/agent"* ]]
}

@test "a link into a home-manager generation is left for home-manager to relink" {
  ln -s /nix/store/aaaa-home-manager-files/.local/bin/agent "$HOME/.local/bin/agent"

  run_sweep
  [ "$status" -eq 0 ]
  [ -L "$HOME/.local/bin/agent" ]
  [ -z "$output" ]
}

@test "an unmanaged regular file is left to backupCommand" {
  printf 'not a link\n' >"$HOME/.local/bin/agent"

  run_sweep
  [ "$status" -eq 0 ]
  [ -f "$HOME/.local/bin/agent" ]
  [ -z "$output" ]
}

@test "paths the generation does not manage are untouched" {
  ln -s /somewhere/else "$HOME/.local/bin/unrelated"

  run_sweep
  [ "$status" -eq 0 ]
  [ -L "$HOME/.local/bin/unrelated" ]
}

@test "DRY_RUN_CMD suppresses the removal but still logs" {
  export DRY_RUN_CMD="echo DRY_RUN:"
  ln -s /somewhere/else/cursor-agent "$HOME/.local/bin/agent"

  run_sweep
  [ "$status" -eq 0 ]
  [ -L "$HOME/.local/bin/agent" ]
  [[ "$output" == *"clearing unmanaged symlink"* ]]
}
