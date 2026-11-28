# Host networking identity and the application firewall, shared by every host.
{ hostConfig, ... }:
{
  networking = {
    # Registry hostname. nix-darwin derives HostName/LocalHostName from it but
    # not ComputerName (the Finder/AirDrop name), so that is set too.
    inherit (hostConfig) hostName;
    computerName = hostConfig.hostName;

    # Application firewall settings; it is on unless a host sets
    # networking.applicationFirewall.disabled (modules/darwin/application-firewall.nix).
    # allowSigned/allowSignedApp keep LAN services (sshd, signed python)
    # accepting inbound.
    applicationFirewall = {
      allowSigned = true;
      allowSignedApp = true;
      blockAllIncoming = false;
      # Stealth: drop unsolicited ICMP/UDP probes instead of answering them.
      # Signed apps and sshd still accept their allowed inbound (allowSigned/
      # allowSignedApp above; the pf anchor separately permits ICMP echo from
      # security.pf.allowedSshSources), so cluster and LAN service traffic is
      # unaffected — this only stops the host announcing itself to a scan.
      enableStealthMode = true;
    };
  };
}
