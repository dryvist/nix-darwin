# Cluster VM-runner gate: the macOS VM runner yields the Mac to a live rank.
#
# Enabled wherever both the Thunderbolt cluster link and the macOS VM runner
# are enabled. A timer drives the runner daemon toward live rank state every
# minute (see ./scripts/cluster-vm-runner-gate.sh), so no operator or AI step
# is part of a cluster cycle.
#
# The runner's VM memory is what the cluster budget needs while a rank serves.
# A job still running on a VM when a rank goes live is interrupted: booting the
# daemon out sends SIGTERM to sand, and the VM is torn down with the job.
#
# The timer interval is short (60s, against the maintenance window's 600s)
# because the runner's VM memory is the thing that must be free before a rank
# serves, and a 10-minute lag would leave it resident through a rank start.
#
# WHICH "CLUSTERED". The gate uses mlx-cluster-rank-live, the same detector as
# the rebuild gate (which refuses activation) and the maintenance window (which
# opens and closes the hands-off window). Three reasons, all from this repo:
#   - It is the single definition the repo's own enforcement and coordination
#     consumers share; a second definition could disagree with the window.
#   - It reads live launchd state with no marker file. The documented
#     "link-state up AND armed true" pair (cluster-zero notes) is written by
#     the nix-ai watcher outside this repo, and a file-based state can latch.
#   - The rebuild gate's block window opens at rank activation, so this gate's
#     transitions line up with the ones the gate already enforces.
# Known gap, shared with the rebuild gate and the window: between arming and
# rank start (link up, armed, no rank yet) rank-live reports not clustered, so
# the runner keeps running until the rank is live.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  runner = config.programs.macos-vm-runner;

  gatePkg = pkgs.writeShellApplication {
    name = "cluster-vm-runner-gate";
    runtimeEnv = {
      MLX_CLUSTER_RANK_LIVE_BIN = lib.getExe config.system.clusterRebuildGate.rankLivePackage;
      VM_RUNNER_LABEL = runner.launchdLabel;
      VM_RUNNER_PLIST = "/Library/LaunchDaemons/${runner.launchdLabel}.plist";
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
  };
}
