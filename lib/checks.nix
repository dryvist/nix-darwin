# Nix quality checks - single source of truth for pre-commit and CI
# Used by flake.nix checks output, ensuring DRY principle
{
  pkgs,
  src,
  darwinConfigurations ? { },
}:
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

  # Run the BATS (Bash Automated Testing System) test suite
  # Runs specific shell integration tests from tests/shell/
  shell-tests =
    pkgs.runCommand "check-shell-tests"
      {
        nativeBuildInputs = with pkgs; [
          bats
          bash
          jq
          yq-go
        ];
      }
      ''
        cd ${src}
        for f in test_bats_framework.bats test_check_file_sizes.bats test_verify_symlinks.bats; do
          bats tests/shell/$f
        done
        touch $out
      '';

  # Lint shell scripts with shellcheck
  # Catches common bugs: unquoted variables, undefined vars, useless use of cat, etc.
  # Excludes .git directories and nix store paths
  # --severity=warning: Only fail on warning/error level (not info style suggestions)
  # SC1091: Exclude "not following" errors for external sources (can't resolve in Nix sandbox)
  # Excludes zsh scripts (shellcheck only supports sh/bash/dash/ksh)
  # Loop, skip rules, and failure semantics live in scripts/check-shellcheck-runner.sh
  # (fails if ANY script fails, not just the last; UTF-8 locale for shellcheck output).
  # TODO: Fix info-level issues (SC2086 quoting) in shell scripts for stricter checking
  shellcheck =
    pkgs.runCommand "check-shellcheck"
      {
        SRC_DIR = src;
        SHELLCHECK_BIN = pkgs.lib.getExe pkgs.shellcheck;
      }
      ''
        bash ${../scripts/check-shellcheck-runner.sh}
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
