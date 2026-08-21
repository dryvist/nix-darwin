{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.cribl-edge;

  # ponytail: temporary evidence-gathering for Vikunja nix-ai#1603. Delete
  # this module and its script once that ticket is resolved.
  probeScript = pkgs.writeShellApplication {
    name = "cribl-edge-boot-race-probe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.perl
    ];
    text = builtins.readFile ./scripts/cribl-edge-boot-race-probe.sh;
  };
in
{
  config = lib.mkIf cfg.enable {
    launchd.daemons.cribl-edge-boot-race-probe.serviceConfig = {
      Label = "com.nix-darwin.cribl-edge-boot-race-probe";
      ProgramArguments = [
        "${probeScript}/bin/cribl-edge-boot-race-probe"
        (lib.head config.launchd.daemons.cribl-edge.serviceConfig.ProgramArguments)
      ];
      RunAtLoad = true;
      KeepAlive.PathState."/nix/store" = true;
      StandardOutPath = "/var/log/cribl-boot-race-probe.log";
      StandardErrorPath = "/var/log/cribl-boot-race-probe.log";
    };
  };
}
