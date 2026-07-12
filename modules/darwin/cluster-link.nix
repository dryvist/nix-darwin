# Thunderbolt RDMA link — auto-detected, zero written IP.
#
# The two-Mac clustered mode (nix-ai `programs.mlx.clusterMode`) serves one
# ~353B model split over a direct Thunderbolt cable with Apple RDMA. macOS
# auto-enslaves every Thunderbolt port into the "Thunderbolt Bridge" (bridge0),
# but Apple RDMA needs the cabled port OUT of that bridge with exclusive L2.
#
# This module detects the cabled port at activation (any Thunderbolt
# `enX` with an active link) and detaches it from bridge0. It assigns NO
# address: the interface's automatic IPv6 link-local (fe80::) is the link
# identity, and the clusterMode runtime discovers the peer via all-nodes
# multicast (ff02::1) — so moving the cable to another port needs no edit
# in any repo. Supersedes the static-IP approach (feat/cluster-link-ip /
# PR #1654, closed): no per-Mac interface or address facts are committed.
#
# GATE: JACCL accepting a link-local `[fe80::…%iface]` rendezvous address is
# unvalidated until the next supervised clustered-mode session. If it rejects
# link-local, set `staticAddress` per host (the documented fallback) — the
# detection/detach logic is identical either way.
{ lib, config, ... }:
let
  cfg = config.system.rdmaLink;
in
{
  options.system.rdmaLink = {
    enable = lib.mkEnableOption "unbridged Thunderbolt RDMA link (auto-detected, link-local)";

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "en2";
      description = ''
        Cabled Thunderbolt interface override. Default null = auto-detect:
        the Thunderbolt `enX` port (per `networksetup -listallhardwareports`)
        whose link status is active. Set only if more than one Thunderbolt
        port is cabled and the wrong one wins.
      '';
    };

    staticAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.208.2";
      description = ''
        FALLBACK ONLY: static IPv4 to pin on the link if the JACCL
        link-local spike fails (see module header). Default null = no
        address written anywhere; IPv6 link-local is the link identity.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Runs as root at the end of system activation. `rdmaLink` is NOT a
    # recognized activation-script phase — nix-darwin only emits the named
    # phases (pre/extra/postActivation), so a custom key type-checks but its
    # text is silently dropped. Hook postActivation instead. Idempotent +
    # non-fatal: no cable, or a port already detached, must never fail rebuild.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      (
        rdma_iface=${if cfg.interface != null then lib.escapeShellArg cfg.interface else ''""''}
        if [ -z "$rdma_iface" ]; then
          # Auto-detect: every physical Thunderbolt port's device, first one
          # with an active link wins. "Thunderbolt [0-9]" only — the virtual
          # "Thunderbolt Bridge" port (device bridge0) also starts with
          # "Thunderbolt" and must never be a candidate. A dangling
          # (uncabled) port stays inactive.
          for dev in $(/usr/sbin/networksetup -listallhardwareports \
                        | /usr/bin/awk '/^Hardware Port: Thunderbolt [0-9]/{getline; print $2}'); do
            if /sbin/ifconfig "$dev" 2>/dev/null | /usr/bin/grep -q "status: active"; then
              rdma_iface="$dev"
              break
            fi
          done
        fi
        if [ -z "$rdma_iface" ]; then
          echo "rdmaLink: no cabled Thunderbolt port detected; nothing to do"
        else
          echo "rdmaLink: detaching $rdma_iface from bridge0 (exclusive L2 for Apple RDMA)"
          /sbin/ifconfig bridge0 deletem "$rdma_iface" 2>/dev/null || true
          ${lib.optionalString (cfg.staticAddress != null) ''
            echo "rdmaLink: FALLBACK static address ${cfg.staticAddress}/24 on $rdma_iface"
            /sbin/ifconfig "$rdma_iface" inet ${cfg.staticAddress} netmask 255.255.255.0 2>/dev/null || true
          ''}
        fi
      )
    '';
  };
}
