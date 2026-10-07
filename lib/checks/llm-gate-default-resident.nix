# An enabled LLM gate must forward to the catalog-selected default resident,
# whose worker owns the bounded request queue.
{
  pkgs,
  configs,
  userConfig,
}:
let
  inherit (pkgs) lib;
  userName = userConfig.user.name;
  hostLayer = {
    services.clusterMaintenanceWindow.passwordSecret = "ci-stub#password";
  };
  gatedConfigs = lib.filterAttrs (_: cfg: cfg.config.programs.llm-gate.enable) configs;

  checkConfig =
    cfg:
    let
      evaluated = cfg.extendModules { modules = [ hostLayer ]; };
      hmUsers = evaluated.config.home-manager.users or { };
      primaryUser = hmUsers.${userName} or null;
      contracts =
        if primaryUser == null then { } else primaryUser.programs.mlx.staticResidentContracts or { };
      defaultResidents = lib.filterAttrs (_: contract: contract.roles ? default) contracts;
      hasOneDefaultResident = builtins.length (builtins.attrNames defaultResidents) == 1;
      contract =
        if hasOneDefaultResident then builtins.head (builtins.attrValues defaultResidents) else { };
      gate = evaluated.config.programs.llm-gate;
      activationScript = evaluated.config.system.activationScripts.postActivation.text;
    in
    hasOneDefaultResident
    && contract.queueSize > 0
    && gate.apiUpstreamPort == contract.servicePort
    && lib.hasInfix "SERVING_GATE_PORT=${toString contract.servicePort}" activationScript;

  failures = builtins.filter (passes: !passes) (map checkConfig (lib.attrValues gatedConfigs));
in
assert
  builtins.attrNames gatedConfigs != [ ] || throw "LLM gate check has no enabled host configuration";
assert failures == [ ] || throw "LLM gate must route to its queued default resident";
pkgs.runCommand "check-llm-gate-default-resident" { } ''
  echo "every enabled LLM gate targets its catalog-selected default resident queue"
  touch $out
''
