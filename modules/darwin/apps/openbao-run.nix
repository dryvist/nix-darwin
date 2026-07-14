# openbao-run — the OpenBao replacement for `doppler run`
#
# Installs `openbao-run` system-wide: an AppRole-authenticated env injector that
# reads named secrets from OpenBao and execs a command with them exported, the
# same shape `doppler run -- <cmd>` provided. This removes the external Doppler
# dependency from local serving components (starting with the llm-large gate).
#
# Secret-zero (BAO_ADDR + <DOMAIN>_VAULT_ROLE_ID/_SECRET_ID) is supplied
# ambiently by the openbao keychain resolver; no fetched secret is written to
# disk. `bao` (OpenBao CLI) + jq come from runtimeInputs.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-run;

  openbaoRunScript = pkgs.writeShellApplication {
    name = "openbao-run";
    runtimeInputs = [
      pkgs.openbao
      pkgs.jq
    ];
    text = builtins.readFile ./../scripts/openbao-run.sh;
  };
in
{
  options.programs.openbao-run.enable = lib.mkEnableOption "the OpenBao AppRole env-injection wrapper (doppler run replacement)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ openbaoRunScript ];
  };
}
