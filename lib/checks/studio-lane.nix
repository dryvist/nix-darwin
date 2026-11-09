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
  roleModels = lib.attrValues home.services.aiStack.models;
  qwenId = mlx.roleMap.models.qwen38-27b.id;
  mimoId = mlx.roleMap.models.mimo-9b.id;
  args = studio.config.launchd.user.agents.llm-gate.serviceConfig.ProgramArguments;
  findArgValue =
    flag: values:
    if values == [ ] then
      throw "llm-gate launchd arguments are missing ${flag}"
    else if builtins.head values == flag then
      builtins.elemAt values 1
    else
      findArgValue flag (builtins.tail values);
  caddyfile = findArgValue "--config" args;
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
  expectedSourceRule = "pass in quick proto tcp from { 127.0.0.1 } to any port ${toString gate.apiPort} flags S/SA keep state";
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
  builtins.elem modelId [
    qwenId
    mimoId
  ]
) roleModels;
assert gate.apiPort == 11434;
assert gate.apiUpstreamPort == mlx.roleMap.models.qwen38-27b.servicePort;
assert gate.apiUpstreamPort != mlx.roleMap.models.mimo-9b.servicePort;
assert gate.bindAddresses == [ "127.0.0.1" ];
assert gate.apiMaxUpstreamConnections == 2;
assert mlx.memoryHardLimitGb == 32;
assert mlx.maxResidentWorkers == 2;
assert mlx.modelConcurrencyLimits.${qwenId} == 1;
assert mlx.modelConcurrencyLimits.${mimoId} == 1;
assert mlx.modelAdmissionLimits.${qwenId} == gate.apiMaxUpstreamConnections;
assert mlx.modelAdmissionLimits.${mimoId} == gate.apiMaxUpstreamConnections;
assert studio.config.security.pf.allowedTcpServices == [ ];
assert !studio.config.security.pf.enforce;
assert lib.hasInfix expectedSourceRule sourceProbeAnchor;
pkgs.runCommand "check-studio-lane" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
  grep -Fq 'bind 127.0.0.1' ${caddyfile}
  grep -Fq 'header Authorization "Bearer {env.LLM_LARGE_BEARER_TOKEN}"' ${caddyfile}
  grep -Fq 'respond @unauthorized 401' ${caddyfile}
  grep -Fq 'reverse_proxy 127.0.0.1:${toString gate.apiUpstreamPort}' ${caddyfile}
  grep -Fq 'versions 1.1' ${caddyfile}
  grep -Fq 'max_conns_per_host ${toString gate.apiMaxUpstreamConnections}' ${caddyfile}
  touch $out
''
