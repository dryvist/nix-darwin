# Declarative Homebrew installation (nix-homebrew)
#
# nix-darwin's `homebrew` module (modules/darwin/homebrew.nix) manages the
# Brewfile — taps/brews/casks — but does NOT install the `brew` binary itself.
# On a fresh host (e.g. jevans-ms) that means `brew bundle` fails at activation
# with "command not found: brew". nix-homebrew owns the /opt/homebrew prefix so
# the install is part of the closure, not a manual bootstrap step.
#
# Kept in its own module (not flake.nix or homebrew.nix) to stay under the
# per-file size cap. `nix-homebrew` arrives via specialArgs (see flake.nix).

{
  lib,
  nix-homebrew,
  hostConfig,
  anomalyco-tap,
  anthropics-tap,
  ...
}:

let
  # Plain file import (not a module arg), matching modules/darwin/sops.nix —
  # used only for the prefix owner below.
  userConfig = import ../../lib/user-config.nix;
in
{
  imports = [ nix-homebrew.darwinModules.nix-homebrew ];

  nix-homebrew = {
    enable = true;
    taps = lib.optionalAttrs hostConfig.homebrew.enableWorkstationApps {
      "anomalyco/tap" = anomalyco-tap;
      "anthropics/tap" = anthropics-tap;
    };
    # Apple Silicon only — no Intel (Rosetta) prefix needed.
    enableRosetta = false;
    # User that owns /opt/homebrew (same across every host).
    user = userConfig.user.name;
    # Adopt an existing manual install (macbook-m4) instead of failing.
    autoMigrate = true;
    # Custom workstation taps are pinned flake inputs, so activation can keep
    # the tap directory immutable.
    mutableTaps = false;
  };
}
