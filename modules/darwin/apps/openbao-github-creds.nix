# OpenBao-backed GitHub token provider
#
# Installs `openbao-github-creds` system-wide so `git` (as a credential helper)
# and `gh`/shell functions can resolve GitHub App installation tokens from
# OpenBao's GitHub secrets engine on demand. Retires the local tiered-PAT
# keychain services (GH_PAT_*). Three tiers: ambient all-repo READ, per-repo
# WRITE behind a `claim` (which also takes a cross-agent lease), and inert
# human-gated admin — see the script header for the full contract.
#
# Secret-zero — VAULT_ADDR + the github-read / github-write AppRole
# role_id/secret_id (and the two installation IDs for write) — is supplied
# AMBIENTLY by the environment, in practice by running under `doppler run` (the
# iac secret store injects them by name). There is deliberately NO local
# keychain in this path, identical to openbao-aws-creds.nix after #1686: Doppler
# holds the OpenBao bootstrap, OpenBao serves the GitHub tokens. `security` etc.
# are not used here; jq + curl come from runtimeInputs, and date/id/scutil are
# resolved from the system PATH (macOS-only host).
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
