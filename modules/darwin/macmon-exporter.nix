# macmon Prometheus exporter: GPU active residency and power metrics on
# /metrics, scraped by the homelab Prometheus for accelerator busy %.
_: {
  launchd.daemons.macmon-exporter.serviceConfig = {
    Label = "dev.local.macmon-exporter";
    ProgramArguments = [
      "/run/current-system/sw/bin/macmon"
      "serve"
      "--port"
      "9090"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    StandardOutPath = "/var/log/macmon-exporter.log";
    StandardErrorPath = "/var/log/macmon-exporter.log";
  };
}
