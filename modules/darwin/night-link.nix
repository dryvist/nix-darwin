# Thunderbolt RDMA link — static point-to-point IP on the cabled port.
#
# The two-Mac night cluster (nix-ai `programs.mlx.nightCluster`) serves one
# ~353B model split over a direct Thunderbolt cable with Apple RDMA. macOS
# auto-enslaves every Thunderbolt port into the "Thunderbolt Bridge" (bridge0)
# with a link-local address, but Apple RDMA needs the cabled port OUT of that
# bridge, holding its own static IP on the synthetic /24 that matches
# `programs.mlx.nightCluster.linkIps`. This assigns that at activation.
#
# `interface` and `address` are per-Mac physical facts (which Thunderbolt port
# the cable is in, this Mac's end of the link) and are set per host in
# hosts/<label>/default.nix. ponytail: restated here rather than derived across
# the home-manager boundary; a morning refactor could read nightCluster directly.
{ lib, config, ... }:
let
  cfg = config.system.rdmaLink;
in
{
  options.system.rdmaLink = {
    enable = lib.mkEnableOption "static IP on the unbridged Thunderbolt RDMA link";

    interface = lib.mkOption {
      type = lib.types.str;
      example = "en2";
      description = "Cabled Thunderbolt interface (the ibv device name minus its rdma_ prefix).";
    };

    address = lib.mkOption {
      type = lib.types.str;
      example = "192.168.208.2";
      description = "This Mac's IPv4 on the link (its role's entry in nightCluster.linkIps).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Runs as root at the end of system activation. `rdmaLink` is NOT a
    # recognized activation-script phase — nix-darwin only emits the named
    # phases (pre/extra/postActivation), so a custom key type-checks but its
    # text is silently dropped. Hook postActivation instead. Detach the cabled
    # port from the auto Thunderbolt bridge (Apple RDMA needs exclusive L2 on
    # the link), then pin the static point-to-point address. Idempotent +
    # non-fatal: no cable, or a port already detached, must never fail rebuild.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "rdmaLink: pinning ${cfg.interface} -> ${cfg.address}/24 (detach from bridge0)"
      /sbin/ifconfig bridge0 deletem ${cfg.interface} 2>/dev/null || true
      /sbin/ifconfig ${cfg.interface} inet ${cfg.address} netmask 255.255.255.0 2>/dev/null || true
    '';
  };
}
