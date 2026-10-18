# RDMA and Thunderbolt link checks

Use these checks to confirm RDMA and link preparation before a manual join.
For physical setup and Recovery-mode RDMA enablement, see
[TB5-RDMA-CLUSTER.md](TB5-RDMA-CLUSTER.md). For join and detach, see
[CLUSTER_MODE.md](CLUSTER_MODE.md).

## RDMA

- On each host, `rdma_ctl status` reports `enabled`.
- On each host, `ibv_devices` lists the Thunderbolt RDMA device. A successful
  ping confirms only the IP path; it does not confirm RDMA.

## Thunderbolt link preparation

- Connect one Thunderbolt cable directly between the two hosts.
- Confirm the Thunderbolt Bridge network service is disabled and no Thunderbolt
  interface is a member of the bridge.
- Confirm Thunderbolt interfaces are up. The carrier-active interface carries
  the address for its configured cluster role; inactive interfaces do not.
- `system.clusterLinkPrep` applies these settings during activation and at
  boot. The manual join checks link preparation before starting ranks.
