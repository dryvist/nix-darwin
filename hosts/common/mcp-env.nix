# Credentials for nix-ai's MCP servers, for every account (imported through
# home-manager sharedModules in flake.nix). nix-ai only names each server's
# env_vars; this sets its programs.aiMcp.envLauncher, the one place those
# values are resolved (scripts/mcp-env.sh).
{
  lib,
  pkgs,
  osConfig,
  nix-ai,
  ...
}:
let
  dopplerSelectors = (import "${nix-ai}/vars/ai-stack.nix").doppler;

  # Servers read from OpenBao under a dedicated AppRole. A server not listed
  # here takes its values from Doppler.
  openbaoServers = {
    vikunja = {
      domain = "vikunja-mcp";
      secrets = {
        VIKUNJA_API_TOKEN = "ai/mcp/vikunja#VIKUNJA_MCP_TOKEN_RW";
        VIKUNJA_URL = "ai/mcp/vikunja#VIKUNJA_MCP_URL";
      };
    };
  };

  mcpEnv = pkgs.writeShellApplication {
    name = "mcp-env";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.doppler
      osConfig.programs.openbao-run.package
    ];
    runtimeEnv = {
      MCP_ENV_DOPPLER_PROJECT = dopplerSelectors.project;
      MCP_ENV_DOPPLER_CONFIG = dopplerSelectors.config;
      MCP_ENV_TABLE = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: server:
          lib.concatStringsSep " " (
            [
              name
              server.domain
            ]
            ++ lib.mapAttrsToList (var: ref: "${var}=${ref}") server.secrets
          )
        ) openbaoServers
      );
    };
    text = builtins.readFile ./scripts/mcp-env.sh;
  };
in
{
  programs.aiMcp = {
    envLauncher = lib.getExe mcpEnv;
    servers.vikunja.disabled = lib.mkForce false;
  };
}
