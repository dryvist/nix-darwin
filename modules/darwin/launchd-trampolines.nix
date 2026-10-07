{
  config,
  lib,
  pkgs,
  ...
}:

let
  trampoline = import ../../lib/launchd-trampoline.nix { inherit lib pkgs; };
  prefix = "${trampoline.systemDirectory}/";

  # Every system job whose first program lives in the trampoline directory
  # gets its trampoline installed; the list is read from the rendered jobs.
  firstPrograms = map (job: lib.head (job.serviceConfig.ProgramArguments or [ "" ])) (
    lib.attrValues config.launchd.daemons ++ lib.attrValues config.launchd.user.agents
  );
  jobNames = lib.unique (
    map (lib.removePrefix prefix) (lib.filter (lib.hasPrefix prefix) firstPrograms)
  );
in
{
  _module.args.launchdTrampolineArgs = trampoline.programArguments trampoline.systemDirectory;

  system.activationScripts.preActivation.text = lib.mkBefore (
    trampoline.install {
      directory = trampoline.systemDirectory;
      names = jobNames;
      owner = {
        user = "root";
        group = "wheel";
      };
    }
  );
}
