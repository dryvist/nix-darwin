# Remove Built-In Apple Applications
#
# Enforces removal of unwanted Apple bundled apps (iWork, iLife, …) on every
# darwin-rebuild. Matched by CFBundleIdentifier (robust to Apple's display-name
# quirks — e.g. Keynote ships as "Keynote Creator Studio.app" on macOS 26 but
# keeps bundle id com.apple.Keynote). Runs as root during activation.
#
# The removal loop lives in scripts/remove-builtin-apps.sh (no inline shell in
# .nix); this module just passes the configured bundle ids to it as arguments.
#
# SCOPE LIMIT: only apps under /Applications can be removed. Everything in
# /System/Applications (Music, TV, Podcasts, News, Home, Chess, Maps, …) is
# SIP-protected and cannot be removed without disabling SIP — deliberately out
# of scope. Set the list per host class (see hosts/common/default.nix, gated on
# isServer) — this is a lean-server hygiene lever, not a per-host one.

{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.remove-builtin-apps;
in
{
  options.programs.remove-builtin-apps.removeBundleIds = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      CFBundleIdentifiers of Apple built-in apps under /Applications to remove
      (and keep removed) on every darwin-rebuild. Only /Applications is in
      scope; /System/Applications is SIP-protected. Idempotent — re-removes if a
      macOS update ever reinstalls the app.
    '';
    example = [
      "com.apple.Keynote"
      "com.apple.Numbers"
      "com.apple.iMovieApp"
    ];
  };

  config = lib.mkIf (cfg.removeBundleIds != [ ]) {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      ${pkgs.runtimeShell} ${./scripts/remove-builtin-apps.sh} ${lib.escapeShellArgs cfg.removeBundleIds}
    '';
  };
}
