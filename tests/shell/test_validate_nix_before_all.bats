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
  # `/usr/bin/env` is not available in the Nix build sandbox, so use the bash
  # executable running this suite in the stub shebang. Otherwise the stub fails
  # to exec and the empty-mode no-op looks like an evaluation failure.
  {
    echo "#!$(command -v bash)"
    echo 'if [[ "$*" == *lib/homebrew-policy.nix* ]]; then if [[ "$NIX_STUB_MODE" == reviewed ]]; then echo '\''{"exceptions":{"brews":{"fixture":"reviewed"},"casks":{}}}'\''; else echo '\''{"exceptions":{"brews":{},"casks":{}}}'\''; fi; exit 0; fi'
    echo 'case "${NIX_STUB_MODE}" in'
    echo '  fail)  echo "error: attribute '"'"'homebrew'"'"' missing" >&2; exit 1 ;;'
    echo '  empty) echo "[]"; exit 0 ;;'
    echo '  search_fail) if [[ "$1" == search ]]; then echo "search failed" >&2; exit 1; elif [[ "$*" == *homebrew.brews* ]]; then echo '\''[{"name":"fixture"}]'\''; else echo "[]"; fi; exit 0 ;;'
    echo '  no_match) if [[ "$1" == search ]]; then echo "{}"; elif [[ "$*" == *homebrew.brews* ]]; then echo '\''[{"name":"fixture"}]'\''; else echo "[]"; fi; exit 0 ;;'
    echo '  attr_match) if [[ "$1" == search ]]; then pattern=${!#}; path="legacyPackages.aarch64-darwin.group.fixture"; if [[ "$path" =~ $pattern || "different-name" =~ $pattern ]]; then echo '\''{"legacyPackages.aarch64-darwin.group.fixture":{"pname":"different-name"}}'\''; else echo "{}"; fi; elif [[ "$*" == *homebrew.brews* ]]; then echo '\''[{"name":"fixture"}]'\''; elif [[ "$*" == *homebrew.casks* ]]; then echo "[]"; else echo true; fi; exit 0 ;;'
    echo '  match|reviewed|unsupported|metadata_fail) if [[ "$1" == search ]]; then [[ "$*" == *"--inputs-from . --system aarch64-darwin"* ]] || exit 9; echo '\''{"legacyPackages.aarch64-darwin.group.renamed":{"pname":"fixture"}}'\''; elif [[ "$*" == *homebrew.brews* ]]; then echo '\''[{"name":"fixture"}]'\''; elif [[ "$*" == *homebrew.casks* ]]; then echo "[]"; elif [[ "$NIX_STUB_MODE" == metadata_fail ]]; then exit 1; elif [[ "$NIX_STUB_MODE" == unsupported ]]; then echo false; else echo true; fi; exit 0 ;;'
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

@test "a failed pinned search aborts instead of reporting a clean run" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=search_fail DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [[ $output == *"pinned nixpkgs search failed"* ]]
}

@test "a successful search with no matches is clean" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=no_match DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ $output == *"not in nixpkgs"* ]]
}

@test "a nested renamed package with a matching pname fails the check" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=match DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [[ $output == *"VIOLATION"* ]]
}

@test "a nested matching attribute with a different pname fails the check" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=attr_match DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [[ $output == *"VIOLATION"* ]]
}

@test "an explicitly reviewed channel passes" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=reviewed DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ $output == *"reviewed"* ]]
}

@test "an unsupported package is not treated as available" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=unsupported DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
}

@test "a metadata evaluation failure aborts" {
  run env PATH="$STUB_DIR:$PATH" NIX_STUB_MODE=metadata_fail DARWIN_HOST=testhost \
    bash "$SCRIPT_UNDER_TEST"
  [ "$status" -ne 0 ]
  [[ $output == *"could not evaluate metadata"* ]]
}
