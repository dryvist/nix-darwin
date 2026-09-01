# Nix quality checks - single source of truth for pre-commit and CI
# Used by flake.nix checks output, ensuring DRY principle
{
  pkgs,
  src,
  darwinConfigurations ? { },
}:
let
  # The stray-symlink sweep (../hosts/common/hm-collision-clear.nix) is inlined
  # into that module rather than a standalone .sh file. Extracting the text
  # here, at ordinary Nix evaluation time, lets the bats test below exercise it
  # without needing `nix eval` (and therefore recursive-nix) inside the
  # sandboxed check derivation. `lib.hm.dag.entryBefore` is the only `lib`
  # function that module calls; a stand-in returning its `text` argument
  # unwrapped is enough to evaluate it standalone.
  hmCollisionClearSweep =
    (import ../hosts/common/hm-collision-clear.nix {
      lib.hm.dag.entryBefore = _: text: text;
    }).home.activation.clearStrayLinkTargets;
in
{
  # Check Nix formatting with nixfmt
  # Uses treefmt configured with nixfmt formatter
  # Copy source to writable $TMPDIR since treefmt needs to write temp files
  formatting =
    pkgs.runCommand "check-formatting"
      {
        nativeBuildInputs = [ pkgs.nixfmt ];
      }
      ''
        cp -r ${src} $TMPDIR/src
        chmod -R u+w $TMPDIR/src
        cd $TMPDIR/src
        ${pkgs.lib.getExe pkgs.treefmt} --fail-on-change --no-cache --formatters nixfmt .
        touch $out
      '';

  # Lint Nix files for anti-patterns and code smells
  # Catches common mistakes and suggests improvements
  statix = pkgs.runCommand "check-statix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.statix} check .
    touch $out
  '';

  # Check for unused Nix code — dead bindings AND unused function args.
  # --fail: exit with error if any unused binding is found.
  # NOTE: deliberately NOT passing -L. `-L` suppresses unused lambda pattern
  # names (function args), which is exactly how an orphaned `pkgs` arg sat on
  # main undetected (introduced in #1251, caught only in #1490). A module must
  # declare only the args it uses.
  deadnix = pkgs.runCommand "check-deadnix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.deadnix} --fail .
    touch $out
  '';

  # Lint standalone shell scripts. Scripts wrapped by writeShellApplication are
  # already checked during their builds, but repository helpers under scripts/
  # otherwise have no ShellCheck coverage.
  shellcheck = pkgs.runCommand "check-shellcheck" { } ''
    set -o pipefail
    cd ${src}
    find ./scripts -name "*.sh" -print0 | \
    xargs -0 bash -c '
      failed=0
      for script in "$@"; do
        # ShellCheck does not support zsh.
        read -r shebang < "$script" || true
        if [[ "$shebang" == *zsh* ]]; then
          echo "Skipping zsh script: $script"
        else
          echo "Checking $script..."
          if ! ${pkgs.lib.getExe pkgs.shellcheck} --severity=warning --exclude=SC1091 "$script"; then
            failed=1
          fi
        fi
      done
      exit "$failed"
    ' bash
    touch $out
  '';

  # Run the BATS (Bash Automated Testing System) test suite
  # Runs specific shell integration tests from tests/shell/
  #
  # THIS LIST DRIFTS, AND THE DRIFT IS SILENT. It is maintained by hand while
  # the files it names live in a directory anyone can add to, so a new test is
  # inert until someone remembers this line — nothing fails, nothing warns, the
  # check just quietly covers less than it appears to. As of this commit four
  # files on disk were absent from it, one of which is currently failing; that
  # failure had gone unnoticed precisely because it never ran.
  #
  # The real fix is to glob tests/shell/*.bats so the list cannot disagree with
  # the directory. That is deliberately NOT done here: globbing immediately
  # turns those pre-existing failures red, which belongs in its own change with
  # the failures actually fixed — not smuggled into an unrelated one, and
  # certainly not "fixed" by excluding the file that fails.
  shell-tests =
    pkgs.runCommand "check-shell-tests"
      {
        nativeBuildInputs = with pkgs; [
          bats
          bash
          jq
          yq-go
        ];
        HM_COLLISION_CLEAR_SWEEP = hmCollisionClearSweep;
      }
      ''
        cd ${src}
        for f in test_bats_framework.bats test_check_ci_invariants.bats test_check_file_sizes.bats test_cluster_maintenance_window.bats test_cluster_rebuild_gate.bats test_cribl_llm_classifier.bats test_hm_collision_clear.bats test_openbao_github_creds.bats test_openbao_slack_creds.bats test_verify_symlinks.bats; do
          bats tests/shell/$f
        done
        touch $out
      '';

  # Guard the macOS build workflow's cost-control invariants (cache scope, the
  # timeout cap, develop-exempt cancellation, cache sizing, prefix restore).
  #
  # These held only as comments before, and a comment did not stop the
  # cache-scoping regression from recurring in the very file that documented it.
  # Asserting them here makes a violation a red required check instead of a
  # silent multi-GB cold build. Rationale per invariant lives in the script.
  ci-invariants =
    pkgs.runCommand "check-ci-invariants"
      {
        nativeBuildInputs = [ pkgs.bash ];
      }
      ''
        cd ${src}
        bash scripts/workflows/check-ci-invariants.sh \
          .github/workflows/_nix-build.yml \
          .github/workflows/ci-nix.yml \
          .github/workflows/ci-gate.yml
        touch $out
      '';

}
// pkgs.lib.optionalAttrs (darwinConfigurations != { }) {
  # Evaluate darwinConfigurations to catch import errors, type errors, and assertion failures
  # Uses .system.drvPath for eval-only (no full build)
  module-eval = pkgs.runCommand "check-module-eval" { } ''
    ${pkgs.lib.concatStringsSep "\n" (
      pkgs.lib.mapAttrsToList (name: cfg: "echo \"${name}: ${cfg.system.drvPath}\"") darwinConfigurations
    )}
    touch $out
  '';
}
