#!/usr/bin/env bats
# Test validate-nix-before-all.sh evaluation-failure handling
#
# The script's whole job is to refuse a config where a homebrew package has a
# nixpkgs equivalent. Before this suite existed, `eval_names` sent stderr to
# /dev/null and ended with `|| true`, so a FAILED `nix eval` produced empty
# output, both lists came back empty, and the script printed "No homebrew
# packages to validate" and exited 0 — indistinguishable from a clean run.
#
# The first case below fails against that older form and passes against the
# current one. The second pins the behaviour that must NOT change with it: an
# empty list that evaluated successfully is still a legitimate no-op.

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../../scripts/validate-nix-before-all.sh"

setup() {
  STUB_DIR=$(mktemp -d)
  # A `nix` whose behaviour is chosen per test. Only `eval` is ever reached:
  # DARWIN_HOST short-circuits host discovery, and both lists coming back empty
  # returns before any `nix search`.
  # The stub gets the shebang of the bash actually running the suite, matching
  # the convention in test_cluster_maintenance_window.bats: `/usr/bin/env` is
  # not available in the Nix build sandbox these tests run in, so a
  # `#!/usr/bin/env bash` stub fails to exec. That exec failure made `nix eval`
  # return non-zero, so the empty-mode no-op looked like a failed evaluation and
  # aborted — the empty path was never actually exercised.
  {
    echo "#!$(command -v bash)"
    echo 'case "${NIX_STUB_MODE}" in'
    echo '  fail)  echo "error: attribute '"'"'homebrew'"'"' missing" >&2; exit 1 ;;'
    echo '  empty) echo "[]"; exit 0 ;;'
    echo 'esac'
    echo 'echo "unexpected nix invocation: $*" >&2; exit 1'
  } > "$STUB_DIR/nix"
  chmod +x "$STUB_DIR/nix"
}

teardown() {
  rm -rf "$STUB_DIR"
}

@test "a failed homebrew evaluation aborts instead of reporting a clean run" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=fail DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [[ "$output" != *"No homebrew packages to validate"* ]]
  [[ "$output" != *"All homebrew packages validated"* ]]
}

@test "a failed homebrew evaluation says which attribute could not be read" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=fail DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [[ "$output" == *"could not evaluate homebrew.brews"* ]]
  [[ "$output" == *"refusing to report a clean run"* ]]
}

@test "an empty but successful list is still a valid no-op" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=empty DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No homebrew packages to validate"* ]]
}
