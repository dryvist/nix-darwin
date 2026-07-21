# OpenBao-backed GitHub token provider
#
# Installs `openbao-github-creds`, the OpenBao GitHub App token provider used by
# git and the interactive `gh-*` helpers. The canonical operational contract,
# including `gh-claim` / `gh-release`, is
# https://docs.dryvist.com/d/runbooks/github-token-openbao-migration/; do not
# duplicate it here.
#
# The helper consumes ambient OpenBao secret-zero (`BAO_ADDR`, with legacy
# `VAULT_ADDR` accepted) only at invocation time. It stores no GitHub token or
# bootstrap material locally; jq and curl are its only runtime dependencies.
#
# This module is purely additive: it ships the wrapper on PATH but changes no
# git/gh config. The interactive cutover (pointing git's credential helper +
# useHttpPath at this wrapper, then deleting the GH_PAT_* keychain services) is
# an operator step — see docs-starlight's github-token-openbao-migration
# runbook — so enabling this module cannot break the keychain-backed path.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-github-creds;

  githubCredsScript = pkgs.writeShellApplication {
    name = "openbao-github-creds";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
    ];
    text = builtins.readFile ./../scripts/openbao-github-creds.sh;
  };
in
{
  options.programs.openbao-github-creds.enable = lib.mkEnableOption "the OpenBao-backed GitHub token provider (git credential helper + gh env source)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ githubCredsScript ];
  };
}
