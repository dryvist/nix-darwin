{
  config,
  lib,
  pkgs,
  ...
}:

let
  trampoline = import ../../lib/launchd-trampoline.nix { inherit lib pkgs; };
  enabledAgents = lib.filterAttrs (_: agent: agent.enable) config.launchd.agents;
  trampolineDirectory = trampoline.homeDirectory config.home.homeDirectory;

  toAgent =
    name: agent:
    let
      agentConfig = agent.config;
      originalArguments =
        lib.optional (agentConfig.Program != null) agentConfig.Program
        ++ lib.optionals (agentConfig.ProgramArguments != null) agentConfig.ProgramArguments;
    in
    pkgs.writeText "${agentConfig.Label}.plist" (
      lib.generators.toPlist { escape = true; } (
        (builtins.removeAttrs agentConfig [
          "Program"
          "ProgramArguments"
        ])
        // {
          ProgramArguments = trampoline.programArguments trampolineDirectory name originalArguments;
        }
      )
    );

  agentPlists = lib.mapAttrs' (
    name: agent: lib.nameValuePair "${agent.config.Label}.plist" (toAgent name agent)
  ) enabledAgents;

  agentsDrv = pkgs.runCommand "home-manager-launchd-agents" { } ''
    mkdir -p "$out"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: path: "ln -s ${lib.escapeShellArg (toString path)} \"$out/\"${lib.escapeShellArg name}"
      ) agentPlists
    )}
  '';
in
{
  home.extraBuilderCommands = lib.mkIf config.launchd.enable (
    lib.mkAfter ''
      rm -f "$out/LaunchAgents"
      ln -s "${agentsDrv}" "$out/LaunchAgents"
    ''
  );

  home.activation.installLaunchdTrampolines = lib.mkIf config.launchd.enable (
    lib.hm.dag.entryBefore [ "setupLaunchAgents" ] (
      trampoline.install {
        directory = trampolineDirectory;
        names = lib.attrNames enabledAgents;
      }
    )
  );
}
