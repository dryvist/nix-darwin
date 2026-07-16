# OpenBao-backed GitHub token provider
#
# Installs `openbao-github-creds` system-wide so `git` (as a credential helper)
# and shell `gh-*` functions (via `openbao-github-creds token <purpose>`) can
# resolve a purpose-scoped GitHub token from OpenBao KV on demand. Retires the
# local tiered-PAT keychain services (GH_PAT_*).
#
# Secret-zero — VAULT_ADDR + the GitHub AppRole role_id/secret_id — is supplied
# AMBIENTLY by the environment, in practice by running under `doppler run` (the
# iac secret store injects them by name). There is deliberately NO local
# keychain in this path, identical to openbao-aws-creds.nix after #1686: Doppler
# holds the OpenBao bootstrap, OpenBao serves the GitHub tokens. `security` etc.
# are not used here; jq + curl come from runtimeInputs.
#
# This module is purely additive: it ships the wrapper on PATH but changes no
# git/gh config. The interactive cutover (pointing git's credential helper and
# the gh-* shell functions at this wrapper, then deleting the GH_PAT_* keychain
# services) is an operator step — see terraform-proxmox's
# docs/github-token-openbao-migration runbook — so enabling this module cannot
# break the current keychain-backed token path.

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
