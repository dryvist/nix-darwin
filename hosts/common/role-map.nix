# Host LLM serving derived from the role map (programs.mlx.roleMap): catalog
# selection, preload roles, per-model concurrency, resident-worker count and
# the role registry all come from the map entry for hostConfig.class. Hosts
# state only runtime posture; no model or role is repeated here. A host that
# serves a model wider than the shared catalog does says so once in its own
# `modelConcurrency`, keyed by role-map model key.
#
# The registry holds exactly the roles the map assigns to this host class, so
# the nix-ai static-serving assertion checks every registry role against the
# LiteLLM aliases compiled for this class.
{
  config,
  lib,
  hostConfig,
  ...
}:
let
  projection = import ../../lib/role-map-host.nix {
    inherit lib;
    inherit (config.programs.mlx) roleMap;
    concurrency = hostConfig.modelConcurrency or { };
  } hostConfig.class;
in
{
  config = lib.mkIf (hostConfig ? mlx) {
    programs.mlx = {
      inherit (projection)
        catalog
        maxResidentWorkers
        preload
        modelConcurrencyLimits
        ;
    };
    services.aiStack.models = projection.aiStackModels;
  };
}
