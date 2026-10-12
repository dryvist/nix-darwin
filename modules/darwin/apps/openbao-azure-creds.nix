# OpenBao-minted Azure credentials for one command.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-azure-creds;

  openbaoAzureCreds = pkgs.writeShellApplication {
    name = "openbao-azure-creds";
    runtimeInputs = [
      pkgs.azure-cli
      pkgs.coreutils
      pkgs.jq
      pkgs.openbao
    ];
    text = builtins.readFile ./../scripts/openbao-azure-creds.sh;
  };
in
{
  options.programs.openbao-azure-creds = lib.mkEnableOption "the OpenBao-backed Azure credential wrapper";

  config = lib.mkIf cfg {
    environment.systemPackages = [ openbaoAzureCreds ];
  };
}
