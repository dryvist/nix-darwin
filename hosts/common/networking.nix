# Host networking identity and the application firewall, shared by every host.
{ hostConfig, ... }:
{
  networking = {
    # Registry hostname. nix-darwin derives HostName/LocalHostName from it but
    # not ComputerName (the Finder/AirDrop name), so that is set too.
    inherit (hostConfig) hostName;
    computerName = hostConfig.hostName;

    # Application firewall on every host. The MBP had this enabled by hand; the
    # Studio shipped disabled, which left the firewall-log-shipping feed with
    # nothing to say (its `log stream` daemon was alive but the ALF subsystem
    # was silent). allowSigned/allowSignedApp match the working MBP posture so
    # LAN services (sshd, llama-swap via signed python) keep accepting inbound.
    applicationFirewall = {
      enable = true;
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
