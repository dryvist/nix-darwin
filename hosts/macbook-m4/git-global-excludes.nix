# Global git excludes, sourced live from the dryvist org-default
# (.github/configs/gitignore) — secrets, credentials, TF state, and
# AI-assistant local state. Merges with nix-home's base `programs.git.ignores`
# (home-manager concatenates the list across modules) and writes to the XDG
# global excludes file, protecting EVERY repo on this machine — including
# non-dryvist clones the per-repo .gitignore can't reach.
#
# `pathExists` guard: tolerates the file being absent on the pinned input
# (e.g. before dryvist/.github#43 merges configs/gitignore to main). Absent =>
# empty list => no-op. After merge, `nix flake update dotgithub` activates it.
#
# Kept in its own module (not home.nix) to stay under the per-file size cap and
# avoid a statix multiple-`programs`-assignment lint.
{
  lib,
  dotgithub,
  ...
}:
let
  f = "${dotgithub}/configs/gitignore";
in
{
  programs.git.ignores = lib.optionals (builtins.pathExists f) (
    lib.filter (l: l != "" && !(lib.hasPrefix "#" l)) (
      map (lib.removeSuffix "\r") (lib.splitString "\n" (builtins.readFile f))
    )
  );
}
