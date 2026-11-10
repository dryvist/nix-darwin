# Host capabilities injected into every darwin and home-manager module as
# hostConfig. Every capability defaults off; host classes opt in here.
{ lib }:

let
  default = {
    homebrew = {
      cleanup = "zap";
      enableWorkstationApps = false;
      # The Ghostty terminal cask, and its Dock tile.
      ghostty = false;
      ai = {
        antigravityDesktop = false;
        antigravityIde = false;
        chatgptDesktop = false;
        claudeDesktop = false;
        codexDesktop = false;
        goose = false;
        langgraphCli = false;
      };
    };
  };

  # AI CLIs come from Nix on every host; servers add only goose.
  server = lib.recursiveUpdate default {
    homebrew.ai.goose = true;
  };

  # Workstations add graphical applications to the shared CLI baseline.
  workstation = lib.recursiveUpdate server {
    homebrew = {
      # `check` aborts activation and lists every installed cask or formula this
      # configuration does not declare; it never deletes one.
      cleanup = "check";
      enableWorkstationApps = true;
      ghostty = true;
      ai = {
        antigravityDesktop = true;
        antigravityIde = true;
        chatgptDesktop = true;
        claudeDesktop = true;
      };
    };
  };
in
{
  inherit default server workstation;
}
