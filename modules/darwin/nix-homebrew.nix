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
  config,
  lib,
  nix-homebrew,
  hostConfig,
  anomalyco-tap,
  anthropics-tap,
  homebrew-core,
  homebrew-cask,
  ...
}:

let
  # Plain file import (not a module arg), matching modules/darwin/sops.nix —
  # used only for the prefix owner below.
  userConfig = import ../../lib/user-config.nix;

  # Every tap brew is asked to use: declared taps plus the user/repo prefix of
  # tap-qualified names (user/repo/formula), which brew bundle taps implicitly.
  usedTaps = lib.unique (
    map (t: t.name) config.homebrew.taps
    ++ map (n: lib.concatStringsSep "/" (lib.take 2 (lib.splitString "/" n))) (
      builtins.filter (n: builtins.length (lib.splitString "/" n) == 3) (
        map (x: x.name) (config.homebrew.casks ++ config.homebrew.brews)
      )
    )
  );
  # brew's user/repo tap name lives at Taps/<user>/homebrew-<repo>.
  tapPath =
    name:
    let
      parts = lib.splitString "/" name;
    in
    "${builtins.elemAt parts 0}/homebrew-${builtins.elemAt parts 1}";
in
{
  imports = [ nix-homebrew.darwinModules.nix-homebrew ];

  nix-homebrew = {
    enable = true;
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
    }
    # Keys are Taps/<user>/<repo> paths; brew only recognizes homebrew-* repos.
    // lib.optionalAttrs hostConfig.homebrew.enableWorkstationApps {
      "anomalyco/homebrew-tap" = anomalyco-tap;
      "anthropics/homebrew-tap" = anthropics-tap;
    };
    # Apple Silicon only — no Intel (Rosetta) prefix needed.
    enableRosetta = false;
    # User that owns /opt/homebrew (same across every host).
    user = userConfig.user.name;
    # Adopt an existing manual install (macbook-m4) instead of failing.
    autoMigrate = true;
    # Every tap is a pinned flake input, so activation can keep the tap
    # directory immutable.
    mutableTaps = false;
  };

  # brew bundle cleanup aborts activation on any installed tap the Brewfile omits.
  homebrew.taps = map (lib.replaceStrings [ "/homebrew-" ] [ "/" ]) (
    builtins.attrNames config.nix-homebrew.taps
  );

  # With immutable taps, a tap missing here is never installed and brew falls
  # back to a live clone, bypassing the lock. Fail the build instead.
  assertions = map (name: {
    assertion = config.nix-homebrew.taps ? ${tapPath name};
    message = "Homebrew tap ${name} has no pinned source: add nix-homebrew.taps.\"${tapPath name}\" (a flake = false input).";
  }) usedTaps;
}
