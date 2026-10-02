# mac-studio nix-prebuild

{ lib, hostConfig, ... }:

let
  userConfig = import ../../lib/user-config.nix;
in
{
  # nix-prebuild: warm the darwin closure on a schedule so the next
  # `darwin-rebuild switch` is a near-instant cache hit instead of a cold build.
  # Builds `develop`, the ref this host converges from; it can also be run on
  # demand right after a merge (`launchctl kickstart -k gui/<uid>/<Label>`).
  #
  # The `develop` literal below is DELIBERATE and must stay `develop` even
  # after this file exists on `main` post-promotion — this job pre-warms the
  # next promotion's source branch, not whatever this file's own branch is.
  # Do not "fix" it to `main`, `HEAD`, or a derived value; that would warm the
  # wrong ref and silently defeat the job.
  # Plain launchd agent (no claude, no token) — inline ProgramArguments, logs to
  # ~/Library/Logs/nix-prebuild/, Background priority.
  #
  # The nix binary is the daemon's own (Determinate installs it under the
  # default profile; nothing links it into /run/current-system/sw/bin). A
  # program path that does not exist makes launchd fail the spawn with
  # EX_CONFIG and the agent never runs.
  launchd.user.agents.nix-prebuild.serviceConfig = {
    Label = "com.nix-darwin.nix-prebuild";
    ProgramArguments = [
      "/nix/var/nix/profiles/default/bin/nix"
      "build"
      "github:dryvist/nix-darwin/develop#darwinConfigurations.${hostConfig.hostName}.system"
      "--no-link"
      "--print-build-logs"
    ];
    StartCalendarInterval = [
      {
        Hour = 4;
        Minute = 30;
      }
    ];
    ProcessType = "Background";
    StandardOutPath = "${userConfig.user.homeDir}/Library/Logs/nix-prebuild/nix-prebuild.log";
    # nix writes build progress to stderr; one file keeps the log readable.
    StandardErrorPath = "${userConfig.user.homeDir}/Library/Logs/nix-prebuild/nix-prebuild.log";
    EnvironmentVariables = {
      HOME = userConfig.user.homeDir;
      PATH = "/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin:/bin";
    };
  };

  # nix-prebuild writes to its own log dir; create it with user ownership.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -o ${userConfig.user.name} -g staff "${userConfig.user.homeDir}/Library/Logs/nix-prebuild"
  '';
}
