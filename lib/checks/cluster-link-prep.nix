# cluster-link-prep's interval guard, run against stub ifconfig and networksetup
# (tests/shell/test_cluster_link_prep_guard.bats): the address-present skip makes
# zero mutating calls, the run cases reach the full pass, a repeated decision logs
# once, and the unguarded activation path always runs the full pass.
#
# Darwin-only: the script calls macOS system binaries (awk, grep, sleep) by
# absolute path.
{ pkgs, src }:
pkgs.runCommand "check-cluster-link-prep"
  {
    nativeBuildInputs = [
      pkgs.bats
      pkgs.bash
    ];
  }
  ''
    cd ${src}
    bats --print-output-on-failure tests/shell/test_cluster_link_prep_guard.bats
    touch $out
  ''
