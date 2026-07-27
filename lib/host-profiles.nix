# Host capabilities injected into every darwin and home-manager module as
# hostConfig. Every capability defaults off; host classes opt in here.
{ lib }:

let
  default = {
    homebrew = {
      cleanup = "zap";
      enableWorkstationApps = false;
      ai = {
        antigravityCli = false;
        antigravityDesktop = false;
        antigravityIde = false;
        chatgptDesktop = false;
        claudeCode = false;
        claudeDesktop = false;
        codex = false;
        codexDesktop = false;
        goose = false;
        qwenCode = false;
      };
    };
  };

  # Headless hosts still receive every shared AI CLI.
  server = lib.recursiveUpdate default {
    homebrew.ai = {
      antigravityCli = true;
      claudeCode = true;
      codex = true;
      goose = true;
      qwenCode = true;
    };
  };

  # Workstations add graphical applications to the shared CLI baseline.
  workstation = lib.recursiveUpdate server {
    homebrew = {
      cleanup = "none";
      enableWorkstationApps = true;
      ai = {
        antigravityDesktop = true;
        antigravityIde = true;
        chatgptDesktop = true;
        claudeDesktop = true;
        codexDesktop = true;
      };
    };
  };
in
{
  inherit default server workstation;
}
