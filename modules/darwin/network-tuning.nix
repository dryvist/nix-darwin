# Network Stack Tuning
#
# TCP/socket-buffer sysctls that only matter when serving models over the LAN
# at high throughput (llama-server / LM Studio / a remote MLX endpoint).
# Loopback (local) inference does not need any of this, so the module defaults
# to disabled and every knob defaults to the macOS default (null = leave
# untouched). Exposed purely so the parameters are documented.
#
# The kern/net sysctls are VOLATILE (reset on reboot); when enabled they
# re-apply via a RunAtLoad launchd daemon AND at activation.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.system.networkTuning;
  optStr = v: if v == null then "" else toString v;

  applyScript = pkgs.writeShellApplication {
    name = "network-tuning-apply";
    runtimeInputs = [ ];
    text = builtins.readFile ./scripts/network-tuning.sh;
  };

  netEnv = {
    MAXSOCKBUF = optStr cfg.maxSockBuf;
    TCP_SENDSPACE = optStr cfg.tcpSendSpace;
    TCP_RECVSPACE = optStr cfg.tcpRecvSpace;
    TCP_WIN_SCALE_FACTOR = optStr cfg.tcpWinScaleFactor;
    TCP_AUTORCVBUFMAX = optStr cfg.tcpAutoRcvBufMax;
    TCP_AUTOSNDBUFMAX = optStr cfg.tcpAutoSndBufMax;
  };
in
{
  options.system.networkTuning = {
    enable = lib.mkEnableOption "TCP/socket-buffer tuning for serving models over the network";

    maxSockBuf = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        kern.ipc.maxsockbuf — maximum bytes per socket buffer. Must be >=
        tcpSendSpace + tcpRecvSpace. Typical tuned value 8388608 (8 MB). null =
        leave the macOS default untouched.
      '';
    };

    tcpSendSpace = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "net.inet.tcp.sendspace — default TCP send buffer. Typical tuned value 1048576. null = leave default.";
    };

    tcpRecvSpace = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "net.inet.tcp.recvspace — default TCP receive buffer. Typical tuned value 1048576. null = leave default.";
    };

    tcpWinScaleFactor = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "net.inet.tcp.win_scale_factor — TCP window scale. Typical tuned value 8. null = leave default.";
    };

    tcpAutoRcvBufMax = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "net.inet.tcp.autorcvbufmax — max auto-tuned receive buffer. Typical tuned value 33554432 (32 MB). null = leave default.";
    };

    tcpAutoSndBufMax = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "net.inet.tcp.autosndbufmax — max auto-tuned send buffer. Typical tuned value 33554432 (32 MB). null = leave default.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.maxSockBuf == null
          || cfg.tcpSendSpace == null
          || cfg.tcpRecvSpace == null
          || cfg.maxSockBuf >= cfg.tcpSendSpace + cfg.tcpRecvSpace;
        message = "system.networkTuning.maxSockBuf must be >= tcpSendSpace + tcpRecvSpace.";
      }
    ];

    launchd.daemons.set-network-tuning = {
      serviceConfig = {
        Label = "dev.local.set-network-tuning";
        ProgramArguments = [ (lib.getExe applyScript) ];
        EnvironmentVariables = netEnv;
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/var/log/set-network-tuning.log";
        StandardErrorPath = "/var/log/set-network-tuning.log";
      };
    };

    system.activationScripts.networkTuning.text = ''
      MAXSOCKBUF=${lib.escapeShellArg netEnv.MAXSOCKBUF} \
      TCP_SENDSPACE=${lib.escapeShellArg netEnv.TCP_SENDSPACE} \
      TCP_RECVSPACE=${lib.escapeShellArg netEnv.TCP_RECVSPACE} \
      TCP_WIN_SCALE_FACTOR=${lib.escapeShellArg netEnv.TCP_WIN_SCALE_FACTOR} \
      TCP_AUTORCVBUFMAX=${lib.escapeShellArg netEnv.TCP_AUTORCVBUFMAX} \
      TCP_AUTOSNDBUFMAX=${lib.escapeShellArg netEnv.TCP_AUTOSNDBUFMAX} \
        ${lib.getExe applyScript} || true
    '';
  };
}
