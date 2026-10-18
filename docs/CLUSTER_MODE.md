# MLX cluster: manual join and detach

A direct Thunderbolt 5 cable connects the MacBook Pro coordinator and Mac Studio
worker for distributed MLX inference. Use the operator commands below to form
and tear down the cluster. Both hosts must have matching `nix-ai` and `nix-darwin` revisions,
`mlx` and `mlx-lm` versions, and macOS build.

## Before joining

- RDMA must be enabled on both hosts. See [TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md)
  for the physical setup and Recovery-mode procedure.
- `system.clusterLinkPrep` disables the Thunderbolt Bridge service, removes
  Thunderbolt ports from the bridge, brings the ports up, and configures the
  role link address on the carrier-active port.
- The macOS Application Firewall (ALF) allows the cluster's signed Python
  interpreter.
  The PF rules exempt the Thunderbolt RDMA network while retaining the inbound
  filtering policy for other traffic.
- Each host needs the durable MLX code-signing identity in its login keychain.
  The setup procedure is in `hosts/common/mlx-cluster-signing.nix`.
- Cluster-mode wired ceilings are 90000 MB on the MacBook Pro coordinator and
  102400 MB on the Mac Studio worker, as set in `hosts/common/default.nix`.

## Join

1. Connect the Thunderbolt cable.
2. On the MacBook Pro, run `cluster-join`.
3. The coordinator first drives the worker's join over SSH using
   `programs.mlx.clusterMode.peerSsh`, then performs its own join. Each host
   checks, in order:
   - The kernel-held RDMA protection-domain count leaves the configured reserve
     free, and no rank is alive.
   - Thunderbolt link preparation is ready.
   - The cluster-mode wired ceiling is applied.
   - Configured applications and launchd agents are quiesced using
     `clusterMode.quiesce.apps` and `clusterMode.quiesce.launchdLabels`.
   - Enough memory is available for the rank.
   - The peer handshake confirms matching `nix-ai`, `nix-darwin`, `mlx`,
     `mlx-lm`, and macOS build versions.
   - Launchd starts both ranks in alignment and confirms cluster formation.

Every gate logs `PASS` or `REFUSE` with a reason to
`~/Library/Logs/mlx-cluster/cluster-lifecycle.log`. Exit status 3 means reboot
that host before retrying.

## Detach

On the coordinator, run `cluster-detach`. It performs the coordinator's detach,
then drives the worker's detach. Each host restores its standalone wired
ceiling and re-bootstraps the configured agents. It writes link-state `down`
last.

## Rebuild gate

`darwin-rebuild` refuses to activate while a cluster rank is live on that host.
Run `cluster-detach` before rebuilding.
