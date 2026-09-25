# Split out of default.nix (12 KB file-size gate) rather than raised — see
# modules/darwin/apps/cribl-edge-daemon.nix's header for the standing rule.
#
# GPU/CPU/power metrics for the homelab wall's LAN scraper. Headless and
# always-on, so this is the primary metrics source (see macbook-m4/default.nix
# for the optional laptop side, default off).
_: {
  programs.macmon-exporter.enable = true;
}
