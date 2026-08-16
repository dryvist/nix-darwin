#!/usr/bin/env bats
# Guard that system.clusterLinkPrep.role and programs.mlx.clusterMode.role stay
# sourced from the SAME field. They used to agree only by coincidence (isServer
# happened to match clusterMode.role on both hosts); diverge them again and IP
# pinning and the rank env disagree about which Mac is .1 while looking like an
# inscrutable network fault, not a config error.
#
# ponytail: structural assertion over the source, not a full darwinConfigurations
# eval — the fastest thing that actually catches a re-coupling regression. See
# test_cluster_quiesce.bats for the same pattern in this repo.

SOURCE_UNDER_TEST="$BATS_TEST_DIRNAME/../../hosts/common/default.nix"

@test "clusterLinkPrep.role is read from hostConfig.mlx.clusterMode.role" {
  run grep -nE '^\s*role = hostConfig\.mlx\.clusterMode\.role;' "$SOURCE_UNDER_TEST"
  [ "$status" -eq 0 ]
}

@test "clusterLinkPrep.role no longer re-derives from hostConfig.isServer" {
  run grep -n 'role = if hostConfig.isServer' "$SOURCE_UNDER_TEST"
  [ "$status" -ne 0 ]
}
