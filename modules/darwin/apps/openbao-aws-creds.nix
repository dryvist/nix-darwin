# OpenBao-minted AWS STS credential_process provider
#
# Installs `openbao-aws-creds` system-wide so `aws` (invoked from any shell,
# any PATH) resolves the `credential_process = openbao-aws-creds <role>` line
# in ~/.aws/config. The wrapper mints short-lived AWS STS creds from OpenBao's
# `aws` secrets engine, authenticating with the terraform AppRole.
#
# Secret-zero — VAULT_ADDR + OPENBAO_APPROLE_TERRAFORM_ROLE_ID/_SECRET_ID — is
# supplied AMBIENTLY by the environment, in practice by running terragrunt
# under `doppler run` (the iac secret store injects them by those names). There
# is deliberately NO local keychain in this path: the OpenBao bootstrap lives
# in Doppler, and OpenBao serves everything else. `security`/`date` inside the
# script are hardcoded to their macOS system paths since neither is a nixpkgs
# package; jq + curl come from runtimeInputs.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-aws-creds;

  awsCredsScript = pkgs.writeShellApplication {
    name = "openbao-aws-creds";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
    ];
    text = builtins.readFile ./../scripts/openbao-aws-creds.sh;
  };
in
{
  options.programs.openbao-aws-creds.enable = lib.mkEnableOption "the OpenBao-minted AWS STS credential_process provider";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ awsCredsScript ];
  };
}
