# corosync-qnetd quorum arbiter — a fifth vote for the Proxmox cluster.
#
# Design rationale, the networking-mode decision, the single-qdevice
# constraint, and the failure-mode contract: ./corosync-qnetd-arbiter.md
# (kept out of this file so it stays under the repo's file-size gate).
#
# This module only builds and runs the arbiter side (a Lima Linux VM running
# corosync-qnetd, reachable from the LAN via bridged networking). The
# Proxmox-side corosync-qdevice package and `pvecm qdevice setup` are a
# separate change in a different repo — see the doc for what it needs from
# this host (its LAN IP:5403) once this module is enabled and verified.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.corosync-qnetd-arbiter;

  vmnetSocketPath = "${cfg.dataDir}/vmnet.bridged.sock";
  limaHome = "${cfg.dataDir}/lima-home";
  limaInstance = "corosync-qnetd";

  # Ubuntu LTS cloud image — the only guest OS this module has been written
  # against. corosync-qnetd ships in Ubuntu's universe repo; no other
  # packages are installed.
  limaYaml = pkgs.writeText "corosync-qnetd-lima.yaml" ''
    vmType: "qemu"
    arch: "aarch64"
    images:
      - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
        arch: "aarch64"
    cpus: ${toString cfg.cpus}
    memory: "${cfg.memoryMiB}MiB"
    disk: "${cfg.diskSize}"
    mounts: []
    ssh:
      loadDotSSHPubKeys: false
    networks:
      - socket: "${vmnetSocketPath}"
        interface: "lima0"
    provision:
      - mode: system
        script: |
          #!/bin/sh
          set -eu
          # Ubuntu cloud images ship with ufw inactive by default, so 5403 is
          # already reachable; this only guards against a future base-image
          # change flipping that default.
          if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
            ufw allow 5403/tcp
          fi
          apt-get update
          DEBIAN_FRONTEND=noninteractive apt-get install -y corosync-qnetd
          systemctl enable --now corosync-qnetd
  '';

  vmnetStartScript = pkgs.writeShellApplication {
    name = "corosync-qnetd-vmnet-start";
    runtimeInputs = [ ];
    text = builtins.readFile ./../scripts/corosync-qnetd-vmnet-start.sh;
  };

  vmStartScript = pkgs.writeShellApplication {
    name = "corosync-qnetd-vm-start";
    runtimeInputs = [ pkgs.gnugrep ];
    text = builtins.readFile ./../scripts/corosync-qnetd-vm-start.sh;
  };
in
{
  options.programs.corosync-qnetd-arbiter = {
    enable = lib.mkEnableOption ''
      the corosync-qnetd quorum arbiter (a Lima VM running corosync-qnetd,
      exposed to the LAN via bridged networking). corosync permits exactly
      ONE qdevice per cluster (corosync.conf's `quorum.device` block is a
      single stanza, not a list) — enable this on exactly one of the two Macs
      this module is available on. The other is a standby build: identical
      code, `enable = false`, ready to flip if the primary host is
      decommissioned. See ./corosync-qnetd-arbiter.md
    '';

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "en0";
      description = ''
        Physical LAN interface socket_vmnet bridges the guest onto. The guest
        gets its own DHCP-assigned LAN address on this segment — verify with
        `ifconfig` on the host before enabling.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/corosync-qnetd-arbiter";
      description = "Host directory for the vmnet socket, Lima's state (LIMA_HOME), and logs.";
    };

    cpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "vCPUs for the qnetd guest. qnetd is a lightweight arbitrator; one core is ample.";
    };

    memoryMiB = lib.mkOption {
      type = lib.types.str;
      default = "512";
      description = "Guest memory in MiB.";
    };

    diskSize = lib.mkOption {
      type = lib.types.str;
      default = "8GiB";
      description = "Guest disk size (Lima `disk` field syntax).";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o root -g wheel -m 0700 "${cfg.dataDir}" "${limaHome}"
    '';

    launchd.daemons.corosync-qnetd-vmnet = {
      serviceConfig = {
        Label = "com.nix-darwin.corosync-qnetd-vmnet";
        ProgramArguments = [ "${vmnetStartScript}/bin/corosync-qnetd-vmnet-start" ];
        EnvironmentVariables = {
          SOCKET_VMNET_BIN = "${pkgs.socket-vmnet}/bin/socket_vmnet";
          VMNET_INTERFACE = cfg.lanInterface;
          VMNET_SOCKET_PATH = vmnetSocketPath;
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardErrorPath = "${cfg.dataDir}/vmnet.err.log";
        StandardOutPath = "${cfg.dataDir}/vmnet.out.log";
      };
    };

    launchd.daemons.corosync-qnetd-vm = {
      serviceConfig = {
        Label = "com.nix-darwin.corosync-qnetd-vm";
        ProgramArguments = [ "${vmStartScript}/bin/corosync-qnetd-vm-start" ];
        EnvironmentVariables = {
          LIMACTL_BIN = "${pkgs.lima}/bin/limactl";
          LIMA_INSTANCE = limaInstance;
          LIMA_YAML_PATH = "${limaYaml}";
          LIMA_HOME = limaHome;
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardErrorPath = "${cfg.dataDir}/vm.err.log";
        StandardOutPath = "${cfg.dataDir}/vm.out.log";
        # Give the vmnet daemon a head start so the guest's network device
        # attaches to a live socket on the first boot after a machine restart.
        ThrottleInterval = 10;
      };
    };
  };
}
