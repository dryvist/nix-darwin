# Cluster-Link Prep — RDMA Thunderbolt link preparation + address convergence
#
# The two-Mac clustered mode runs Apple RDMA over a direct Thunderbolt cable.
# JACCL's rendezvous parser is IPv4-only (verified 2026-07-11: every IPv6
# form, including [::1]:port, fails with "Can't parse address"), so the link
# uses role-derived synthetic IPv4 addresses. They are module-defined
# defaults on a deliberately-non-LAN /24 — not site topology; the canonical
# copy lives in nix-ai `programs.mlx.clusterMode.linkIps` and these defaults
# must match it.
#
# Two root-side pieces (user-space cannot do either):
#   1. Activation sweep: every RDMA-capable port (ibv_devices: rdma_enX ->
#      enX) leaves bridge0 (RDMA needs exclusive L2) and gets AUTOMATIC-V6.
#   2. Converge daemon (30s tick): finds the ACTIVE RDMA-capable port and
#      moves this host's link address onto it. Moving the cable to another
#      port converges within one tick — no config change, ever.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.system.clusterLinkPrep;
  userConfig = import ../../lib/user-config.nix;
  convergePkg = pkgs.writeShellApplication {
    name = "cluster-link-converge";
    runtimeInputs = [
      pkgs.gawk
      pkgs.gnugrep
    ];
    text = builtins.readFile ./scripts/cluster-link-converge.sh;
  };
  alfAllowPkg = pkgs.writeShellApplication {
    name = "cluster-alf-allow";
    text = builtins.readFile ./scripts/cluster-alf-allow.sh;
  };
in
{
  options.system.clusterLinkPrep = {
    enable = lib.mkEnableOption "RDMA Thunderbolt link preparation (bridge detach, IPv6, role address convergence)";

    role = lib.mkOption {
      type = lib.types.enum [
        "coordinator"
        "worker"
      ];
      description = "Cluster role; selects which link address this host converges onto the cabled port.";
    };

    linkIps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        # Synthetic point-to-point net for the Thunderbolt cable itself —
        # must match the nix-ai clusterMode.linkIps defaults (canonical).
        coordinator = "192.168.208.1";
        worker = "192.168.208.2";
      };
      description = "Link addresses of the two ends of the Thunderbolt cable.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.cluster-link-converge = {
      serviceConfig = {
        Label = "dev.cluster-link.converge";
        ProgramArguments = [ (lib.getExe convergePkg) ];
        RunAtLoad = true;
        StartInterval = 30;
        EnvironmentVariables.CLUSTER_LINK_IP = cfg.linkIps.${cfg.role};
        StandardOutPath = "/var/log/cluster-link-converge.log";
        StandardErrorPath = "/var/log/cluster-link-converge.error.log";
      };
    };

    # postActivation (root, boot + rebuild): when an RDMA-capable Thunderbolt
    # port is actively cabled, disable the bridge0 network service so macOS
    # stops re-enslaving the port, then detach it from bridge0 and enable IPv6
    # link-local. No active RDMA link → clean no-op with the Thunderbolt Bridge
    # left enabled for ordinary Thunderbolt networking. Shell lives in
    # scripts/cluster-link-prep.sh (readFile, not writeShellApplication, so the
    # intentionally non-fatal steps run without `set -e`).
    system.activationScripts.postActivation.text = lib.mkAfter (
      builtins.readFile ./scripts/cluster-link-prep.sh
      # The JACCL rendezvous listener needs an explicit application-firewall
      # allowance (uv CPython is ad-hoc-signed) — see scripts/cluster-alf-allow.sh.
      + ''
        CLUSTER_USER_HOME="${userConfig.user.homeDir}" ${lib.getExe alfAllowPkg}
      ''
    );
  };
}
