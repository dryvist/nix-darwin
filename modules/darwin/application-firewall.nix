# The fleet's switch for the macOS application firewall. The firewall is on
# unless a host sets `networking.applicationFirewall.disabled = true`.
{ config, lib, ... }:
{
  options.networking.applicationFirewall.disabled = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Turn the macOS application firewall off on this host.";
  };

  config.networking.applicationFirewall.enable = !config.networking.applicationFirewall.disabled;
}
