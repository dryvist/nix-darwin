# Dock app provider contract.
#
# Every Dock entry names the provider that puts its bundle on disk, so a
# provider move cannot leave a stale Dock path behind. `problems` is pure: the
# Dock module turns its result into an assertion on every host build, and
# lib/checks/dock-providers.nix runs it against fixtures.
#
# Providers (exactly one per entry):
#   system  = true;        macOS ships the app
#   cask    = "<token>";   a Homebrew cask in homebrew.casks, installed under /Applications
#   mas     = <id>;        a Mac App Store id in homebrew.masApps, installed under /Applications
#   nixpkgs = "<pname>";   a home-manager package, copied under Home Manager Apps
#   manual  = "<reason>";  installed outside this configuration, with the reason
{ lib }:

let
  providerKinds = [
    "system"
    "cask"
    "mas"
    "nixpkgs"
    "manual"
  ];

  problemsFor =
    {
      homeDir,
      casks,
      masIds,
      pnames,
    }:
    { path, via }:
    let
      kinds = builtins.attrNames via;
      kind = builtins.head kinds;
      value = via.${kind};
      under = prefix: lib.hasPrefix prefix path;
      declaredIn = list: builtins.elem value list;
      expect = ok: message: lib.optional (!ok) "${path}: ${message}";
    in
    if builtins.length kinds != 1 || !(builtins.elem kind providerKinds) then
      [ "${path}: the provider must name exactly one of ${lib.concatStringsSep ", " providerKinds}" ]
    else if kind == "cask" then
      expect (declaredIn casks) "cask \"${value}\" is not in homebrew.casks"
      ++ expect (under "/Applications/") "a cask installs under /Applications"
    else if kind == "mas" then
      expect (declaredIn masIds) "Mac App Store id ${toString value} is not in homebrew.masApps"
      ++ expect (under "/Applications/") "a Mac App Store app installs under /Applications"
    else if kind == "nixpkgs" then
      expect (declaredIn pnames) "package \"${value}\" is not in a home-manager home.packages"
      ++ expect (under "${homeDir}/Applications/Home Manager Apps/") "a nixpkgs app is copied under Home Manager Apps"
    else if kind == "manual" then
      expect (builtins.isString value && value != "") "a manual entry needs a reason"
    else
      expect (value == true) "a system entry is written as system = true";
in
{
  problems = declared: entries: lib.concatMap (problemsFor declared) entries;
}
