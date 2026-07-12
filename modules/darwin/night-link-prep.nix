# Night-Link Prep — RDMA Thunderbolt link preparation + address convergence
#
# The two-Mac night cluster runs Apple RDMA over a direct Thunderbolt cable.
# JACCL's rendezvous parser is IPv4-only (verified 2026-07-11: every IPv6
# form, including [::1]:port, fails with "Can't parse address"), so the link
# uses role-derived synthetic IPv4 addresses. They are module-defined
# defaults on a deliberately-non-LAN /24 — not site topology; the canonical
# copy lives in nix-ai `programs.mlx.nightCluster.linkIps` and these defaults
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
  cfg = config.system.nightLinkPrep;
  convergePkg = pkgs.writeShellApplication {
    name = "night-link-converge";
    runtimeInputs = [
      pkgs.gawk
      pkgs.gnugrep
    ];
    text = builtins.readFile ./scripts/night-link-converge.sh;
  };
in
{
  options.system.nightLinkPrep = {
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
        # must match the nix-ai nightCluster.linkIps defaults (canonical).
        coordinator = "192.168.208.1";
        worker = "192.168.208.2";
      };
      description = "Link addresses of the two ends of the Thunderbolt cable.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.night-link-converge = {
      serviceConfig = {
        Label = "dev.night-link.converge";
        ProgramArguments = [ (lib.getExe convergePkg) ];
        RunAtLoad = true;
        StartInterval = 30;
        EnvironmentVariables.NIGHT_LINK_IP = cfg.linkIps.${cfg.role};
        StandardOutPath = "/var/log/night-link-converge.log";
        StandardErrorPath = "/var/log/night-link-converge.error.log";
      };
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Preparing RDMA-capable Thunderbolt interfaces..."
      if [ -x /usr/bin/ibv_devices ]; then
        /usr/bin/ibv_devices 2>/dev/null | /usr/bin/awk 'NR>2 {print $1}' | while read -r rdma_dev; do
          iface="''${rdma_dev#rdma_}"
          /sbin/ifconfig "$iface" > /dev/null 2>&1 || continue
          if /sbin/ifconfig bridge0 2>/dev/null | /usr/bin/grep -q "member: $iface "; then
            if /sbin/ifconfig bridge0 deletem "$iface"; then
              echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Removed $iface from bridge0"
            else
              echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to remove $iface from bridge0" >&2
            fi
          fi
          if /usr/sbin/ipconfig set "$iface" AUTOMATIC-V6 2>/dev/null; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] IPv6 link-local enabled on $iface"
          else
            echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to enable IPv6 on $iface" >&2
          fi
        done
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ibv_devices not present; skipping RDMA link prep"
      fi
    '';
  };
}
