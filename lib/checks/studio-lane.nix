# Assert the Studio's static router lane and the fail-closed gate defaults.
{
  pkgs,
  studio,
  userConfig,
}:
let
  inherit (pkgs) lib;
  home = studio.config.home-manager.users.${userConfig.user.name};
  mlx = home.programs.mlx;
  gate = studio.config.programs.llm-gate;
  enabledCatalog = lib.filterAttrs (_: selection: selection.enable) mlx.catalog;
  enabledCatalogKeys = lib.sort builtins.lessThan (lib.attrNames enabledCatalog);
  # Model ids of catalog entries the Studio disables; roles may still name them
  # (the shared role map keeps an ocr role) but nothing can load them.
  disabledCatalogIds = map (key: mlx.roleMap.models.${key}.id) (
    lib.attrNames (lib.filterAttrs (_: selection: !selection.enable) mlx.catalog)
  );
  roleModels = lib.attrValues home.services.aiStack.models;
  qwenId = mlx.roleMap.models.qwen38-27b.id;
  mimoId = mlx.roleMap.models.mimo-9b.id;
  args = studio.config.launchd.user.agents.llm-gate.serviceConfig.ProgramArguments;
  findArgValue =
    flag: values:
    if values == [ ] then
      throw "launchd arguments are missing ${flag}"
    else if builtins.head values == flag then
      builtins.elemAt values 1
    else
      findArgValue flag (builtins.tail values);
  caddyfile = findArgValue "--config" args;
  # The Qwen resident runs under mlx-model-server; MiMo has its own static agent.
  qwenServerArgs = home.launchd.agents.mlx-model-server.config.ProgramArguments;
  mimoServerArgs = home.launchd.agents.mlx-static-resident-mimo-9b.config.ProgramArguments;
  sourceListProbe = studio.extendModules {
    modules = [
      {
        security.pf.allowedTcpServices = [
          {
            port = gate.apiPort;
            sources = [ "127.0.0.1" ];
          }
        ];
      }
    ];
  };
  sourceProbeAnchor = sourceListProbe.config.environment.etc."pf.anchors/nix-hardening".text;
  expectedSourceRule = "pass in quick proto tcp from { 127.0.0.1 } to any port ${toString gate.apiPort} no state";
  pf = studio.config.security.pf;
  servicesOn = port: lib.filter (service: service.port == port) pf.allowedTcpServices;
in
assert
  enabledCatalogKeys == [
    "mimo-9b"
    "qwen38-27b"
  ];
assert lib.all (key: enabledCatalog.${key}.class == "resident") enabledCatalogKeys;
assert mlx.models == { };
assert lib.elem qwenId roleModels;
assert lib.elem mimoId roleModels;
assert builtins.all (
  modelId:
  builtins.elem modelId (
    [
      qwenId
      mimoId
    ]
    ++ disabledCatalogIds
  )
) roleModels;
assert gate.apiPort == 11434;
assert findArgValue "--model" qwenServerArgs == qwenId;
assert toString gate.apiUpstreamPort == findArgValue "--port" qwenServerArgs;
assert toString gate.apiUpstreamPort != findArgValue "--port" mimoServerArgs;
assert gate.apiMaxUpstreamConnections == 2;
assert mlx.memoryHardLimitGb == 32;
assert mlx.maxResidentWorkers == 2;
assert mlx.modelConcurrencyLimits.${qwenId} == 1;
assert mlx.modelConcurrencyLimits.${mimoId} == 1;
assert mlx.modelAdmissionLimits.${qwenId} == gate.apiMaxUpstreamConnections;
assert mlx.modelAdmissionLimits.${mimoId} == gate.apiMaxUpstreamConnections;
# Public API passes admit only the SSH sources; router sources come only from
# the private overlay. The cluster pass stays exactly as declared.
assert servicesOn gate.apiPort != [ ];
assert lib.all (service: service.sources == pf.allowedSshSources) (servicesOn gate.apiPort);
assert
  servicesOn gate.clusterPort == [
    {
      sources = pf.allowedSshSources;
      port = gate.clusterPort;
    }
  ];
assert lib.hasInfix expectedSourceRule sourceProbeAnchor;
pkgs.runCommand "check-studio-lane" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  grep -Fq 'header Authorization "Bearer {env.LLM_LARGE_BEARER_TOKEN}"' ${caddyfile}
  grep -Fq 'respond @unauthorized 401' ${caddyfile}
  grep -Fq 'reverse_proxy 127.0.0.1:${toString gate.apiUpstreamPort}' ${caddyfile}
  grep -Fq 'versions 1.1' ${caddyfile}
  grep -Fq 'max_conns_per_host ${toString gate.apiMaxUpstreamConnections}' ${caddyfile}
  touch $out
''
