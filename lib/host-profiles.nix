# Host-class capability profiles injected into every darwin and home-manager
# module as hostConfig. Keep host policy here; modules consume capabilities.
let
  server = {
    homebrew = {
      cleanup = "zap";
      enableWorkstationApps = false;
      ai = {
        claudeCode = true;
        codex = true;
        claudeDesktop = false;
        codexApp = false;
        antigravity = false;
      };
    };
  };
in
{
  default = server;
  inherit server;

  workstation = server // {
    homebrew = server.homebrew // {
      cleanup = "none";
      enableWorkstationApps = true;
      ai = server.homebrew.ai // {
        claudeDesktop = true;
        codexApp = true;
        antigravity = true;
      };
    };
  };
}
