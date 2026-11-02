# Local router host wiring: both Macs use the runtime bearer, and Studio's
# existing launchd watcher probes the same local proxy and reuses its notifier.
{
  pkgs,
  configs,
  hosts,
  userConfig,
  src,
}:
let
  inherit (pkgs) lib;
  userName = userConfig.user.name;
  primaryUser =
    host:
    builtins.getAttr userName (
      builtins.getAttr "users" (
        builtins.getAttr "home-manager" (builtins.getAttr "config" (builtins.getAttr host.hostName configs))
      )
    );
  macbook = primaryUser hosts.macbook-m4;
  studio = primaryUser hosts.mac-studio;

  usesRuntimeBearer =
    cfg:
    cfg.services.aiStack.llmEndpointBearerFromEnv && cfg.services.aiStack.llmEndpointTokenFile == null;

  clientFiles = [
    "hosts/common/home.nix"
    "hosts/mac-studio/home.nix"
    "hosts/macbook-m4/home.nix"
  ];
  staleClientUrl = "http://127.0.0.1:11434";
  hasStaleClientUrl = builtins.any (
    path: lib.hasInfix staleClientUrl (builtins.readFile (src + "/${path}"))
  ) clientFiles;

  watch = studio.launchd.agents.litellm-fallback-watch.config or { };
  watchEnvironment = watch.EnvironmentVariables or { };
  watchHome = studio.home.homeDirectory;
  monitorCoversLocalProxy =
    studio.programs.litellmLocal.enable
    && (watch.Label or null) == "dev.litellm-fallback-watch"
    && (watch.StartInterval or 0) > 0
    &&
      (watchEnvironment.LITELLM_LOCAL_URL or "")
      == lib.removeSuffix "/v1" studio.programs.litellmLocal.baseUrl
    && (watchEnvironment.LITELLM_ALERT_URL_FILE or "") == watchHome + "/.config/mlx-cluster/alert-url";
in
assert
  usesRuntimeBearer macbook
  || throw "macbook-m4 must use llmEndpointBearerFromEnv without a token file";
assert
  usesRuntimeBearer studio
  || throw "mac-studio must use llmEndpointBearerFromEnv without a token file";
assert !hasStaleClientUrl || throw "a Darwin client still hardcodes http://127.0.0.1:11434";
assert
  monitorCoversLocalProxy
  || throw "dev.litellm-fallback-watch must probe litellm-local and reuse the shared Slack webhook";
pkgs.runCommand "check-llm-local-hosts" { } ''
  touch $out
''
