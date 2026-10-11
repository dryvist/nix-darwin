# Reconcile the VM runner with the existing live-rank detector.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  runner = config.programs.macos-vm-runner;
  runnerLabel = config.launchd.daemons.macos-vm-runner.serviceConfig.Label;

  gatePkg = pkgs.writeShellApplication {
    name = "cluster-vm-runner-gate";
    runtimeInputs = [ pkgs.jq ];
    runtimeEnv = {
      MLX_CLUSTER_RANK_LIVE_BIN = lib.getExe config.system.clusterRebuildGate.rankLivePackage;
      VM_RUNNER_LABEL = runnerLabel;
      VM_RUNNER_PLIST = "/Library/LaunchDaemons/${runnerLabel}.plist";
    };
    text = builtins.readFile ./scripts/cluster-vm-runner-gate.sh;
  };
in
{
  config = lib.mkIf (config.system.clusterLinkPrep.enable && runner.enable) {
    launchd.daemons.cluster-vm-runner-gate.serviceConfig = {
      Label = "com.nix-darwin.cluster-vm-runner-gate";
      ProgramArguments = [ (lib.getExe gatePkg) ];
      RunAtLoad = true;
      StartInterval = 60;
      StandardOutPath = "/var/log/cluster-vm-runner-gate.log";
      StandardErrorPath = "/var/log/cluster-vm-runner-gate.log";
    };

    # One line a minute; rotate through the system newsyslog run (root).
    environment.etc."newsyslog.d/cluster-vm-runner-gate.conf".text = ''
      # logfilename [owner:group] mode count size when flags
      /var/log/cluster-vm-runner-gate.log root:wheel 640 3 1024 * BJN
    '';
  };
}
