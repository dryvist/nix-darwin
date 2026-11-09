# macmon Prometheus exporter: GPU active residency and power metrics on
# /metrics, scraped by the homelab Prometheus for accelerator busy %.
{ lib, config, ... }:
{
  options.services.macmon-exporter.port = lib.mkOption {
    type = lib.types.port;
    default = 9090;
    description = "TCP port the macmon exporter serves /metrics on.";
  };

  config.launchd.daemons.macmon-exporter.serviceConfig = {
    Label = "dev.local.macmon-exporter";
    ProgramArguments = [
      "/run/current-system/sw/bin/macmon"
      "serve"
      "--port"
      (toString config.services.macmon-exporter.port)
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    StandardOutPath = "/var/log/macmon-exporter.log";
    StandardErrorPath = "/var/log/macmon-exporter.log";
  };
}
