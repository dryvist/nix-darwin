# Server-room wall monitor: never let the screensaver engage for the
# auto-login user. Display and computer sleep are covered by system.energy
# in ./default.nix; idle time is a separate, ByHost preference this handles.

{ lib, pkgs, ... }:

let
  wallScreensaverDisable = pkgs.writeShellApplication {
    name = "wall-screensaver-disable";
    text = builtins.readFile ./scripts/wall-screensaver-disable.sh;
  };

  userConfig = import ../../lib/user-config.nix;
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ${lib.getExe wallScreensaverDisable} ${userConfig.user.name} || true
  '';
}
