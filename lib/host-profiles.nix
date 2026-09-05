# Host capabilities injected into every darwin and home-manager module as
# hostConfig. Every capability defaults off; host classes opt in here.
{ lib }:

let
  default = {
    aiTooling.tokenMeter = {
      enable = false;
      menuBar = false;
      httpsGate = false;
    };
    homebrew = {
      cleanup = "zap";
      enableWorkstationApps = false;
      ai = {
        antigravityDesktop = false;
        antigravityIde = false;
        chatgptDesktop = false;
        claudeCode = false;
        claudeDesktop = false;
        codex = false;
        codexDesktop = false;
        goose = false;
        langgraphCli = false;
      };
    };
  };

  # Headless hosts still receive every shared AI CLI.
  server = lib.recursiveUpdate default {
    # token-meter measures the Claude Code / Codex CLIs enabled just below, so
    # it belongs to the same tier. httpsGate additionally needs a per-host
    # bindAddress, which cannot come from a shared tier.
    aiTooling.tokenMeter = {
      enable = true;
      menuBar = true;
      httpsGate = true;
    };
    homebrew.ai = {
      claudeCode = true;
      codex = true;
      goose = true;
      langgraphCli = true;
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
