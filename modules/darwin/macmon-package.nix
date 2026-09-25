# macmon — sudoless CPU/GPU/ANE power, temperature and memory monitor for
# Apple Silicon, packaged for the system profile so its stable path
# (/run/current-system/sw/bin/macmon) is consumable by anything that shells
# out to it — e.g. the Cribl Edge Mac pack's Exec source, which reads it via
# `macmon pipe` rather than a per-user install.
#
# nixpkgs (pinned nixpkgs-26.05-darwin) carries macmon 0.6.1. Built here from
# the macmon-src flake input instead — pinned by release tag in flake.nix,
# bumped by renovate.json5's macmon-tag customManager (see its comment for
# why the plain `nix` manager can't) — against its own Cargo.lock, so no
# hand-computed cargoHash lives in this repo. version is read from that same
# source, never duplicated as a literal.
{
  lib,
  pkgs,
  macmon-src,
  ...
}:

let
  cargoToml = fromTOML (builtins.readFile "${macmon-src}/Cargo.toml");

  macmon = pkgs.rustPlatform.buildRustPackage {
    pname = "macmon";
    version = cargoToml.package.version;
    src = macmon-src;
    cargoLock.lockFile = "${macmon-src}/Cargo.lock";
    meta = {
      description = "Sudoless performance monitoring for Apple Silicon processors";
      homepage = "https://github.com/vladkens/macmon";
      license = lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
      mainProgram = "macmon";
    };
  };
in
{
  environment.systemPackages = [ macmon ];
}
