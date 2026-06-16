# Third-Party GUI Application Defaults
#
# macOS preferences for third-party GUI applications.
# Uses system.defaults.CustomUserPreferences to set defaults.
#
# Add new app configuration files here and import them below.

_:

{
  imports = [
    ./ai-volumes.nix
    ./auto-update-prevention.nix
    ./cribl-edge.nix
    ./cribl-stream.nix
    ./orbstack.nix
    ./raycast.nix
    ./streamline-login.nix
  ];

  # OrbStack module is imported but host-specific config (apfsContainer)
  # must be set in hosts/<host>/default.nix
  # Data symlink (in hosts/<host>/home.nix) is only needed if dataVolume.enable is true
  #
  # ai-volumes module is imported but host-specific config (apfsContainer)
  # must be set in hosts/<host>/default.nix
}
