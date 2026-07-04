# Remove Built-In Apple Applications
#
# Enforces removal of unwanted Apple bundled apps (iWork, iLife, …) on every
# darwin-rebuild. Matched by CFBundleIdentifier (robust to Apple's display-name
# quirks — e.g. Keynote ships as "Keynote Creator Studio.app" on macOS 26 but
# keeps bundle id com.apple.Keynote). Runs as root during activation.
#
# SCOPE LIMIT: only apps under /Applications can be removed. Everything in
# /System/Applications (Music, TV, Podcasts, News, Home, Chess, Maps, …) is
# SIP-protected and cannot be removed without disabling SIP — deliberately out
# of scope. Set the list per host class (see hosts/common/default.nix, gated on
# isServer) — this is a lean-server hygiene lever, not a per-host one.

{ lib, config, ... }:

let
  cfg = config.programs.remove-builtin-apps;
  ts = "$(date '+%Y-%m-%d %H:%M:%S')";
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
      echo "${ts} [INFO] Removing unwanted built-in apps..."
      _removed=0
      # POSIX glob: /Applications always has apps, but the `[ -e ]` guard also
      # skips the literal glob if it ever matches nothing.
      for _app in /Applications/*.app; do
        [ -e "$_app" ] || continue
        _bid=$(/usr/bin/defaults read "$_app/Contents/Info" CFBundleIdentifier 2>/dev/null) || continue
        case " ${lib.concatStringsSep " " cfg.removeBundleIds} " in
          *" $_bid "*)
            rm -rf "$_app"
            echo "${ts} [INFO] Removed $_app ($_bid)"
            _removed=$((_removed + 1))
            ;;
        esac
      done
      echo "${ts} [INFO] Built-in app removal complete ($_removed removed)"
    '';
  };
}
