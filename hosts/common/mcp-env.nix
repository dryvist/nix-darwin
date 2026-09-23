# Credentials for nix-ai's MCP servers (imported for every account through
# home-manager sharedModules in flake.nix). nix-ai only names each server's
# env_vars; this sets each credentialed server's launchPrefix, an argv list
# nix-ai prepends to the server command. An account that resolves its values
# differently overrides the prefix in its own home config
# (home-open-llm.nix).
{
  lib,
  pkgs,
  osConfig,
  nix-ai,
  ...
}:
let
  dopplerSelectors = (import "${nix-ai}/vars/ai-stack.nix").doppler;
  dopplerRun = [
    (lib.getExe pkgs.doppler)
    "run"
    "-p"
    dopplerSelectors.project
    "-c"
    dopplerSelectors.config
    "--"
  ];
in
{
  programs.aiMcp.servers = {
    vikunja = {
      disabled = lib.mkForce false;
      # AppRole vikunja-mcp: read-only on secret/ai/mcp/vikunja; its
      # secret-zero comes from Doppler.
      launchPrefix = lib.mkDefault (
        dopplerRun
        ++ [
          (lib.getExe osConfig.programs.openbao-run.package)
          "--domain"
          "vikunja-mcp"
          "--secret"
          "VIKUNJA_API_TOKEN=ai/mcp/vikunja#VIKUNJA_MCP_TOKEN_RW"
          "--secret"
          "VIKUNJA_URL=ai/mcp/vikunja#VIKUNJA_MCP_URL"
          "--"
        ]
      );
    };
    zammad.launchPrefix = lib.mkDefault dopplerRun;
    google-workspace.launchPrefix = lib.mkDefault dopplerRun;
  };
}
