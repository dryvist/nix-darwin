# Apple `container` Runtime Bring-Up (shared one-shot)
#
# Every module that supervises an Apple `container` Linux VM needs the
# per-user container-apiserver running first. This module owns that bring-up
# as ONE launchd one-shot agent, shared by all consumers (cribl-stream,
# github-runner-container) — each sets `enable = lib.mkDefault true` from its
# own config block, so however many consumers a host activates, exactly one
# runtime agent exists.
#
# `container` is per-user (talks to the login user's container-apiserver), so
# this is a user agent, not a root daemon — server hosts run auto-login
# exactly so user agents come up unattended on boot. `container system start`
# is idempotent: a no-op when the apiserver is already up.

{
  lib,
  config,
  ...
}:

let
  cfg = config.programs.apple-container-runtime;
in
{
  options.programs.apple-container-runtime = {
    enable = lib.mkEnableOption "one-shot launchd agent that brings up the Apple container runtime/apiserver";

    containerBin = lib.mkOption {
      type = lib.types.str;
      default = "/opt/homebrew/bin/container";
      description = "Apple container CLI path (Homebrew install). Consumers read this option for their own `container run` invocations.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "macOS login user whose container-apiserver is started (Apple `container` is per-user); owns the log dir.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "staff";
      description = "Primary group of the login user (macOS default: staff).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/apple-container";
      description = "Host directory for the runtime agent's logs.";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${cfg.user} -g ${cfg.group} "${cfg.dataDir}" "${cfg.dataDir}/logs"
    '';

    launchd.user.agents.apple-container-runtime.serviceConfig = {
      Label = "com.nix-darwin.apple-container-runtime";
      ProgramArguments = [
        cfg.containerBin
        "system"
        "start"
        "--enable-kernel-install"
      ];
      RunAtLoad = true;
      StandardErrorPath = "${cfg.dataDir}/logs/apple-container-runtime.err.log";
    };
  };
}
