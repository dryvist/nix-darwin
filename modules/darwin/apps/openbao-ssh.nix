# OpenBao-backed SSH client-CA certificate provider
#
# Installs `openbao-ssh`, the ssh analogue of the openbao-github-creds and
# openbao-aws-creds wrappers. Reaching a managed guest requires a certificate
# signed by the OpenBao SSH client CA; with no wrapper on PATH there is no
# discoverable way to obtain one, so this module ships the single command that
# mints a certificate and hands it straight to ssh.
#
# The helper mints a throwaway ed25519 keypair per invocation, has the CA sign
# it, and revokes its OpenBao token on exit. It caches nothing: no key, no
# certificate and no token outlives the process, and none is written outside a
# private temp directory that is removed when the process ends.
#
# Secret zero — `BAO_ADDR` (legacy `VAULT_ADDR` accepted) plus the ansible
# AppRole pair — is supplied AMBIENTLY by the environment and read only at
# invocation time; the script names the wrapper that provides it when it is
# missing. jq, curl and openssh are its only runtime dependencies.
#
# This module is purely additive: it ships the wrapper on PATH and changes no
# ssh configuration.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-ssh;

  sshScript = pkgs.writeShellApplication {
    name = "openbao-ssh";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
      pkgs.openssh
    ];
    text = builtins.readFile ./../scripts/openbao-ssh.sh;
  };
in
{
  options.programs.openbao-ssh.enable = lib.mkEnableOption "the OpenBao-backed SSH client-CA certificate provider";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ sshScript ];
  };
}
