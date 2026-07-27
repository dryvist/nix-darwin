# Third-Party GUI Application Defaults
#
# macOS preferences for third-party GUI applications.
# Uses system.defaults.CustomUserPreferences to set defaults.
#
# Add new app configuration files here and import them below.

_:

{
  imports = [
    ./agent-log-rotation.nix
    ./ai-cli-log-shipping.nix
    ./apfs-volumes.nix
    ./apple-container-runtime.nix
    ./auto-update-prevention.nix
    ./claude-continuity.nix
    ./cribl-edge.nix
    ./cribl-stream.nix
    ./git-apfs-volume.nix
    ./github-runner-container.nix
    ./openbao-aws-creds.nix
    ./openbao-github-creds.nix
    ./openbao-run.nix
    ./orbstack.nix
    ./raycast.nix
    ./screen-sharing.nix
    ./streamline-login.nix
  ];

  # APFS volumes (HuggingFace, ContainerData) are created by apfs-volumes.nix;
  # host-specific apfsContainer + volume list come from lib/hosts.nix.
  # The OrbStack data symlink (hosts/<host>/home.nix) consumes the ContainerData
  # volume on hosts that run OrbStack.
}
