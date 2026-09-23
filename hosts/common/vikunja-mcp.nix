# Vikunja MCP credentials for this account's agents.
#
# nix-ai's vikunja entry reads VIKUNJA_API_TOKEN and VIKUNJA_URL from its
# environment. This wraps the server command so every launch — interactive or
# not, any harness — fetches both from OpenBao via the existing openbao-run
# (AppRole vikunja-mcp, read-only on secret/ai/mcp/vikunja). Its secret-zero
# comes from `doppler run`.
{
  lib,
  osConfig,
  pkgs,
  nix-ai,
  ...
}:
let
  vikunjaMcp = (import "${nix-ai}/modules/mcp/packages-npm.nix" { inherit pkgs; }).vikunja-mcp;
in
{
  programs.aiMcp.servers.vikunja = {
    disabled = lib.mkForce false;
    command = lib.mkForce (lib.getExe pkgs.doppler);
    args = lib.mkForce [
      "run"
      "-p"
      "ai-ci-automation"
      "-c"
      "prd"
      "--"
      (lib.getExe osConfig.programs.openbao-run.package)
      "--domain"
      "vikunja-mcp"
      "--secret"
      "VIKUNJA_API_TOKEN=ai/mcp/vikunja#VIKUNJA_MCP_TOKEN_RW"
      "--secret"
      "VIKUNJA_URL=ai/mcp/vikunja#VIKUNJA_MCP_URL"
      "--"
      "${vikunjaMcp}/bin/vikunja-mcp"
    ];
    env = lib.mkForce { };
  };
}
