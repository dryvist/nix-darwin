# openbao-run — the OpenBao replacement for `doppler run`
#
# Installs `openbao-run` system-wide: an AppRole-authenticated env injector that
# reads named secrets from OpenBao and execs a command with them exported, the
# same shape `doppler run -- <cmd>` provided. This removes the external Doppler
# dependency from local serving components (starting with the llm-large gate).
#
# Secret-zero (BAO_ADDR + <DOMAIN>_VAULT_ROLE_ID/_SECRET_ID) comes from the
# ambient environment or a caller-supplied 0600 `--env-file` (unattended
# agents); no keychain involvement, no fetched secret written to disk. All
# OpenBao HTTP rides /usr/bin/curl — the Apple PLATFORM binary, exempt from
# macOS Local Network privacy, which silently EHOSTUNREACHes non-platform
# binaries (e.g. a nix-store bao CLI) in GUI-session launchd contexts. jq
# (no network) comes from runtimeInputs for response parsing.
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
      pkgs.jq
    ];
    text = builtins.readFile ./../scripts/openbao-run.sh;
  };
in
{
  options.programs.openbao-run = {
    enable = lib.mkEnableOption "the OpenBao AppRole env-injection wrapper (doppler run replacement)";
    package = lib.mkOption {
      type = lib.types.package;
      default = openbaoRunScript;
      readOnly = true;
      description = "The built openbao-run derivation, for other modules (e.g. llm-gate) to reference in launchd ProgramArguments.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
