# Executable names whose per-process metrics the Cribl Edge system_metrics
# source reports. ./cribl.nix builds one process set per name, matched on the
# executable path (args[0]). The list merges across modules, so a private
# overlay appends names by adding its own definitions.
{ lib, ... }:
{
  options.programs.criblEdgeProcessNames = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Executable names, matched against args[0], that get a per-process
      metric set in the Cribl Edge system_metrics source.
    '';
  };

  config.programs.criblEdgeProcessNames = [
    "WindowServer"
    "cribl"
    "python"
    "node"
    "codex"
    "claude"
    "osascript"
    "gpg-agent"
    "socketfilterfw"
    "runningboardd"
    # Also matches mds_stores.
    "mds"
  ];
}
