{ pkgs }:
let
  inherit (pkgs) lib;
  fixture = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      ../../modules/darwin/apps/claude-continuity.nix
      {
        options = {
          launchd.user.agents = lib.mkOption { type = lib.types.attrs; };
          system.activationScripts = lib.mkOption { type = lib.types.attrs; };
          assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; };
        };
        config.programs.agentSessions = {
          enable = true;
          user = "fixture";
          homeDirectory = "/tmp/agent-session-fixture";
          openFileLimit = 4096;
          sessions.probe = {
            workingDirectory = "/";
            command = [
              "${pkgs.python3}/bin/python3"
              "-c"
              ''import json, os, sys; from pathlib import Path; Path(os.environ["HOME"], "probe.json").write_text(json.dumps({"argv": sys.argv[1:], "env": dict(os.environ), "cwd": os.getcwd()})); input()''
              "argument with spaces"
              "quote'and\"dollar$"
            ];
          };
        };
      }
    ];
  };
  service = fixture.config.launchd.user.agents.agent-session-probe.serviceConfig;
  manifest = pkgs.writeText "agent-session-fixture.json" (
    builtins.toJSON {
      inherit service;
      tmux = "${pkgs.tmux}/bin/tmux";
    }
  );
in
assert lib.all (entry: entry.assertion) fixture.config.assertions;
pkgs.runCommand "check-agent-sessions" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 ${../../tests/agent-sessions.py} ${manifest} | tee $out
''
