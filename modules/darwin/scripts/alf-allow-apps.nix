# One package for alf-allow-apps.sh, shared by pf-hardening.nix and cluster-link-prep.nix.
{ pkgs }:
pkgs.writeShellApplication {
  name = "alf-allow-apps";
  text = builtins.readFile ./alf-allow-apps.sh;
}
