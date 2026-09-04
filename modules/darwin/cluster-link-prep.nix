# Cluster-Link Prep — static Thunderbolt RDMA link configuration
#
# The two-Mac clustered mode runs Apple RDMA over a direct Thunderbolt cable.
# JACCL's rendezvous parser is IPv4-only (verified 2026-07-11: every IPv6
# form, including [::1]:port, fails with "Can't parse address"), so the link
# uses role-derived synthetic IPv4 addresses. They are module-defined
# defaults on a deliberately-non-LAN /24 — not site topology; the canonical
# copy lives in nix-ai `programs.mlx.clusterMode.staticLinkIps` and these
# defaults must match it.
#
# Everything is applied by one idempotent root pass, triggered at rebuild
# (postActivation) and again at boot (a RunAtLoad LaunchDaemon). Still no
# runtime daemon: nothing polls, nothing stays resident. macOS
# SystemConfiguration persists most of the settings, but not all of them —
# see the boot trigger below for what a reboot undoes:
#   1. The "Thunderbolt Bridge" network service is disabled, so macOS never
#      enslaves a Thunderbolt port into bridge0 (RDMA needs exclusive L2).
#   2. Every physical Thunderbolt port's network service gets the SAME manual
#      role IPv4. Only one port is ever cabled to the peer, and inactive
#      services install no routes, so whichever port the cable lands in
#      carries the address — moving the cable needs no config change.
#
# The wired-memory ceiling flip around rank start/stop lives with the
# cluster watcher (nix-ai, user agent); sysctl needs root, so this module
# emits exact-value sudoers grants for it.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.system.clusterLinkPrep;
  userConfig = import ../../lib/user-config.nix;
  tunables = config.system.appleSiliconTunables;
  prepPkg = pkgs.writeShellApplication {
    name = "cluster-link-prep";
    text = builtins.readFile ./scripts/cluster-link-prep.sh;
  };
  alfAllowPkg = pkgs.writeShellApplication {
    name = "cluster-alf-allow";
    text = builtins.readFile ./scripts/cluster-alf-allow.sh;
  };
in
{
  options.system.clusterLinkPrep = {
    enable = lib.mkEnableOption "static Thunderbolt RDMA link configuration (bridge service off, role IPv4 on every Thunderbolt port)";

    role = lib.mkOption {
      type = lib.types.enum [
        "coordinator"
        "worker"
      ];
      description = "Cluster role; selects which link address this host's Thunderbolt ports carry.";
    };

    linkIps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        # Synthetic point-to-point net for the Thunderbolt cable itself —
        # must match the nix-ai clusterMode.staticLinkIps defaults (canonical).
        coordinator = "192.168.208.1";
        worker = "192.168.208.2";
      };
      description = "Link addresses of the two ends of the Thunderbolt cable.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      # The synthetic /24 linkIps above live on — shared here (rather than a
      # second literal) so modules/darwin/pf-hardening.nix's default
      # security.pf.exemptNetworks can pass cluster rendezvous traffic
      # without ever being able to drift from the addresses this module
      # actually assigns.
      default = "192.168.208.0/24";
      description = "CIDR containing both cluster linkIps addresses.";
    };

    clusterWiredLimitMb = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      example = 90000;
      description = ''
        iogpu.wired_limit_mb to hold while a cluster rank is serving — sized
        for this node's pipeline SHARD plus KV headroom, never the whole
        pooled model, and low enough that the GUI working set stays unwirable.
        A shard sized above this ceiling can wire out WindowServer.
        The cluster watcher (nix-ai) applies it before rank start and restores
        the standalone value (appleSiliconTunables.wiredLimitMb, else the
        macOS default) at link-down, via the exact-value sudoers grants this
        module emits. null = no grants, watcher never touches the sysctl.
        Values are UNVALIDATED until the first supervised plug session.

        Fed into nix-ai programs.mlx.clusterMode.wiredLimitMb by
        hosts/common/home.nix so the watcher/lifecycle-command env actually
        carries CLUSTER_WIRED_LIMIT_MB — without that wiring the pin is inert.
      '';
    };

    standaloneWiredLimitMb = lib.mkOption {
      type = lib.types.int;
      readOnly = true;
      default = if tunables.enable then tunables.wiredLimitMb else 0;
      description = ''
        Computed standalone-serving wired ceiling the watcher restores at
        link-down: appleSiliconTunables.wiredLimitMb when that module is
        enabled, else 0 (= macOS default ceiling). Read-only — the single
        source consumed by BOTH the exact-value sudoers grant emitted here and
        nix-ai programs.mlx.clusterMode.standaloneWiredLimitMb (wired in
        hosts/common/home.nix), so the granted value and the value the watcher
        restores can never drift.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Exact-value grants only: a wildcard on the value would let any user
    # process wire arbitrary amounts (and sudoers globs can span spaces,
    # opening injection of additional sysctl assignments).
    environment.etc."sudoers.d/cluster-wired-limit" = lib.mkIf (cfg.clusterWiredLimitMb != null) {
      # Deduped: on a host where the clustered ceiling equals the standalone
      # ceiling (e.g. the headless server) the two grants collapse to one line
      # instead of a redundant duplicate.
      text =
        let
          grantValues = lib.unique [
            cfg.clusterWiredLimitMb
            cfg.standaloneWiredLimitMb
          ];
          grantLine =
            v:
            "${userConfig.user.name} ALL=(ALL) NOPASSWD: /usr/sbin/sysctl -w iogpu.wired_limit_mb=${toString v}";
        in
        ''
          # Clustered/standalone wired-ceiling flips for the mlx cluster watcher.
          # Generated by nix-darwin - do not edit manually
          ${lib.concatMapStringsSep "\n" grantLine grantValues}
        '';
    };

    # Boot trigger (root, RunAtLoad): the SAME prep, one more time to run it.
    #
    # This repo deliberately does not run a full activation at boot —
    # ./boot-activation.nix restores only the /run/current-system symlink,
    # because full activation early in boot trips App Management prompts. So
    # postActivation below fires at REBUILD time and never at boot, while
    # macOS re-enslaves every Thunderbolt port into bridge0 across a reboot
    # and drops the role alias. The link therefore stayed unconfigured after
    # every restart until someone ran `activate` by hand on both nodes, and
    # the watcher — whose only link test is a ping to the peer address — read
    # that as a pulled cable.
    #
    # Idempotent and self-limiting: the prep is the same one-shot pass, and
    # the daemon exists only while clusterLinkPrep is enabled, so a host with
    # cluster mode off installs nothing.
    launchd.daemons.cluster-link-prep.serviceConfig = {
      Label = "com.nix-darwin.cluster-link-prep";
      # /nix/store is not guaranteed mounted when launchd starts root daemons;
      # wait4path first, exactly as ./boot-activation.nix does.
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${lib.getExe prepPkg}"
      ];
      EnvironmentVariables.CLUSTER_LINK_IP = cfg.linkIps.${cfg.role};
      RunAtLoad = true;
      KeepAlive = false;
      StandardOutPath = "/var/log/cluster-link-prep.log";
      StandardErrorPath = "/var/log/cluster-link-prep.log";
    };

    # postActivation (root, rebuild): idempotent one-shot link config;
    # never allowed to fail activation.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      CLUSTER_LINK_IP=${
        lib.escapeShellArg cfg.linkIps.${cfg.role}
      } ${lib.getExe prepPkg} || echo "cluster-link-prep: non-fatal failure (see log above)"
      # The JACCL rendezvous listener needs an explicit application-firewall
      # allowance (uv CPython is ad-hoc-signed) — see scripts/cluster-alf-allow.sh.
      CLUSTER_USER_HOME="${userConfig.user.homeDir}" ${lib.getExe alfAllowPkg} || echo "cluster-alf-allow: non-fatal failure (see log above)"
    '';
  };
}
