# Resolver settings come from DHCP, and this list is what keeps them that way.
#
# nix-darwin applies `networking.dns` and `networking.search` — both left at
# their empty defaults here, which it renders as "use DHCP" — only to the
# services named below, skipping any a host does not have. With the list empty,
# activation asserts nothing about resolvers at all, so a resolver set locally
# on an interface persists across every rebuild.
#
# Physical interfaces only. A VPN service supplies its own resolver while
# connected, so naming one here would clear the setting it needs to work.

{ ... }:

{
  networking.knownNetworkServices = [
    "Wi-Fi"
    "USB 10/100/1000 LAN"
    "USB-C Triple-4K Dock"
    "AX88179A"
  ];
}
