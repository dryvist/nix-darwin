# The launchd daemon entry for Cribl Edge, split out for the per-file byte cap.
#
# It lives in its own file because modules/darwin/apps/cribl-edge.nix crossed
# the 12 KB error limit and .file-size.yml says, in as many words: if it fails
# this gate, SPLIT IT, do not raise the limit. This block is the clean cut —
# a self-contained attrset with no indented-string fragment to re-indent, which
# is the hazard that makes the equivalent split in hosts/common/cribl.nix hard.
#
# Everything here is serviceConfig plus the reasoning for it. The caller passes
# what the block reads and nothing else, so the surface between the two files
# is the argument list below.
{
  lib,
  cfg,
  startScript,
  startArgs,
  declaredConfigSha,
  userConfig,
}:
{
  serviceConfig = {
    Label = "com.nix-darwin.cribl-edge";
    # /nix is a separate APFS volume mounted by the async RunAtLoad
    # `systems.determinate.nix-store` daemon, so a bare
    # /nix/store/... argv0 is missing when launchd first spawns this
    # daemon at cold boot: launchd logs "Missing executable detected",
    # marks the service inactive, and never re-arms it (observed both
    # Macs, and again on the reboot that produced this fix). What
    # revived it 3m31s later was activation's
    # launchd-self-heal, which only runs postActivation — so absent a
    # darwin-rebuild the daemon stays dead for the rest of the uptime.
    #
    # `KeepAlive.PathState` does NOT fix this, despite two prior attempts
    # resting on the belief that it does. PathState governs
    # restart-after-exit only: it gates neither the RunAtLoad spawn nor
    # any re-arm after a spawn that failed with ENOENT. Do not re-add it.
    #
    # /bin/sh and /bin/wait4path live on the System volume and are always
    # present pre-mount. This is the same idiom nix-darwin already
    # generates for org.nixos.activate-system on this host.
    #
    # STANDALONE EXECS CRIBL DIRECTLY. There is nothing left for a wrapper
    # to decide here: the data directories are created in activation, the
    # declarative config is installed in activation, and the managed-state
    # retirement is a one-shot migration that also moved to activation. All
    # the wrapper did on this path was re-derive a mode that is known at
    # build time and then exec the same binary. The remaining `/bin/sh -c`
    # is the mount-wait above, not a wrapper.
    #
    # MANAGED KEEPS THE WRAPPER, because enrolment genuinely needs run-time
    # work: reading a secrets file, parsing the leader URL into token, host,
    # port and group, and enrolling before the server starts. None of that
    # is expressible in a plist. No host here sets mode = "managed", so this
    # branch is untested by any live converge — treat it as legacy support
    # rather than a supported path, and if it ever gains a user, exercise it
    # before trusting it.
    ProgramArguments = [
      "/bin/sh"
      "-c"
      (
        if cfg.mode == "standalone" then
          "/bin/wait4path /nix/store && exec ${cfg.package}/opt/cribl/bin/cribl server"
        else
          "/bin/wait4path /nix/store && exec ${startScript}/bin/cribl-edge-start ${startArgs}"
      )
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    UserName = cfg.serviceUser;
    GroupName = cfg.serviceGroup;
    WorkingDirectory = cfg.dataDir;
    StandardOutPath = "${cfg.dataDir}/logs/cribl-stdout.log";
    StandardErrorPath = "${cfg.dataDir}/logs/cribl-stderr.log";
    # Cribl does not hot-reload config written from outside its own API
    # (see the extraActivation note above), so a config-only generation
    # left the running daemon on stale config until reboot. Hashing the
    # declared config into the plist makes nix-darwin's launchd phase
    # restart the daemon exactly when config content changes — the env
    # var itself is inert to Cribl.
    EnvironmentVariables = {
      CRIBL_DECLARED_CONFIG_SHA256 = declaredConfigSha;
      # Let the codex/gemini pack file inputs resolve their
      # $CODEX_HOME/$GEMINI_HOME transcript paths from the Edge process env.
      CODEX_HOME = "${userConfig.user.homeDir}/.codex";
      GEMINI_HOME = userConfig.user.homeDir;
    }
    // lib.optionalAttrs (cfg.mode == "standalone") {
      # Exported by the wrapper until now. `cribl server` reads both from
      # its environment, so with the wrapper gone they have to be declared
      # here or the daemon starts against the package's own default paths
      # and writes its state into the store path instead of dataDir.
      CRIBL_VOLUME_DIR = cfg.dataDir;
      CRIBL_HOME = "${cfg.package}/opt/cribl";
    };
  };
}
