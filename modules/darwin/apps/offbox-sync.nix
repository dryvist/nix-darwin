# One-way off-box replication of local data directories to a remote SFTP target.
#
# WHY `copy` AND NEVER `sync`
#
# The point of this module is that the workstation keeps a short local window
# while the remote keeps full history. `rclone sync` makes the destination
# match the source, so the moment local retention prunes a directory the remote
# copy is deleted too — silently, and exactly when the archive is the only copy
# left. `rclone copy` never deletes at the destination. That asymmetry IS the
# feature; do not "fix" it by switching verbs.
#
# WHY A SKIP EXITS NON-ZERO
#
# The predecessor of this module was a launchd agent that, with no target
# configured, printed "no backup target configured — skipping" and exited 0. It
# did that on every run for months while nothing was backed up, and every
# health check agreed it was fine. Here, a missing env file or an unreadable
# target is a FAILURE: non-zero exit, and a fact with status="misconfigured".
# Silence must never be indistinguishable from success.
#
# WHY THE AGENT IS DECLARED HERE AND NOT INSTALLED BY A SCRIPT
#
# A launchd plist written by an installer points into /nix/store without being
# a GC root. `nix-collect-garbage` then deletes the target and the agent fails
# with "no such file" forever — observed on this machine. Declaring it through
# nix-darwin makes the store path a GC root by construction.
#
# BASH 3.2
#
# launchd starts this through Apple's /bin/bash (3.2.57). No `declare -A`, no
# `mapfile`, and no `case` inside `$( )` — that last one mis-parses and is the
# reason a sibling watcher silently returned garbage.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.offboxSync;

  jobModule = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Short identifier; appears in the emitted facts.";
      };
      source = lib.mkOption {
        type = lib.types.str;
        description = "Absolute local path to replicate from.";
      };
      dest = lib.mkOption {
        type = lib.types.str;
        description = "Remote path under the SFTP root, e.g. \"data\".";
      };
      immutable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Treat already-transferred files as never changing. Correct for
          date-partitioned capture output, where a changed file means
          corruption and should surface as an error rather than a silent
          overwrite. Must be false for mutable trees (notes, transcripts).
        '';
      };
      maxAge = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "36h";
        description = ''
          Only consider files newer than this. Combined with --no-traverse it
          is what makes a short interval viable against a tree with hundreds of
          thousands of files: the remote is never listed, only the few
          candidates are stat'd. Leave null for mutable trees, where an edit to
          an old file must still replicate.
        '';
      };
      backupDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Remote path under which overwritten versions are preserved, dated per
          run. Use for mutable trees so an edit cannot destroy the prior
          remote copy.
        '';
      };
    };
  };

  # `--min-age` is applied to every job: a file still being written (an
  # in-flight video chunk, a half-flushed frame) must not be copied mid-write.
  mkJobArgs =
    job:
    lib.concatStringsSep " " (
      [
        "copy"
        (lib.escapeShellArg job.source)
        (lib.escapeShellArg ":sftp:\${OFFBOX_ROOT}/${job.dest}")
        "--min-age ${cfg.minAge}"
        "--transfers ${toString cfg.transfers}"
        "--checkers ${toString cfg.checkers}"
        "--sftp-concurrency ${toString cfg.transfers}"
        "--sftp-host \"\${OFFBOX_HOST}\""
        "--sftp-user \"\${OFFBOX_USER}\""
        "--sftp-key-file \"\${OFFBOX_KEY_FILE}\""
        # Host-key validation stays ON. rclone silently disables it unless a
        # known_hosts file is named, which would make a MITM on this path
        # invisible; the estate's standing rule is that host-key checking is
        # never traded for convenience.
        "--sftp-known-hosts-file \"\${OFFBOX_KNOWN_HOSTS}\""
        "--stats-one-line"
        "--stats 1m"
      ]
      ++ lib.optional job.immutable "--immutable"
      ++ lib.optional (job.maxAge != null) "--max-age ${job.maxAge} --no-traverse"
      ++ lib.optional (
        job.backupDir != null
      ) "--backup-dir \":sftp:\${OFFBOX_ROOT}/${job.backupDir}/$(date -u +%Y%m%d)\""
    );

  runner = pkgs.writeShellScript "offbox-sync" ''
    set -u
    LOG="$HOME/Library/Logs/offbox-sync"
    mkdir -p "$LOG"
    FACTS="$LOG/offload.jsonl"

    emit() {
      # $1 job, $2 status, $3 duration_s, $4 detail
      printf '{"ts":"%s","host":"%s","mechanism":"offbox_sync","job":"%s","status":"%s","duration_s":%s,"detail":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname -s)" "$1" "$2" "$3" "$4" >> "$FACTS"
    }

    if [ ! -r "${cfg.envFile}" ]; then
      # NOT exit 0. See the module header.
      emit "-" "misconfigured" 0 "env file unreadable: ${cfg.envFile}"
      echo "offbox-sync: env file unreadable: ${cfg.envFile}" >&2
      exit 1
    fi
    set -a
    . "${cfg.envFile}"
    set +a

    for v in OFFBOX_HOST OFFBOX_USER OFFBOX_KEY_FILE OFFBOX_ROOT OFFBOX_KNOWN_HOSTS; do
      eval "val=\''${$v:-}"
      if [ -z "$val" ]; then
        emit "-" "misconfigured" 0 "$v unset"
        echo "offbox-sync: $v unset" >&2
        exit 1
      fi
    done

    rc_total=0
    ${lib.concatMapStringsSep "\n" (job: ''
      start=$(date +%s)
      ${pkgs.rclone}/bin/rclone ${mkJobArgs job} >> "$LOG/${job.name}.log" 2>&1
      rc=$?
      dur=$(( $(date +%s) - start ))
      if [ "$rc" -eq 0 ]; then
        emit "${job.name}" "ok" "$dur" ""
      else
        emit "${job.name}" "fail" "$dur" "rclone rc=$rc"
        rc_total=1
      fi
    '') cfg.jobs}

    exit "$rc_total"
  '';
in
{
  options.programs.offboxSync = {
    enable = lib.mkEnableOption "one-way off-box replication of local data directories";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose LaunchAgent domain the job runs in.";
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to a file defining OFFBOX_HOST, OFFBOX_USER, OFFBOX_KEY_FILE,
        OFFBOX_ROOT and OFFBOX_KNOWN_HOSTS. Kept out of the Nix store and out
        of this repo: the target's hostname is not public. Render it with
        sops-nix using the `userOnly` shape so a LaunchAgent can read it
        without Keychain access, which root-run activation does not have.
      '';
    };

    jobs = lib.mkOption {
      type = lib.types.listOf jobModule;
      default = [ ];
      description = "Directories to replicate. Inert when empty.";
    };

    intervalSeconds = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = ''
        How often to run. 300 s is the practical floor for a large tree over
        wifi and sets the RPO for new data; sub-minute buys nothing here
        because per-file round-trips, not bandwidth, are the constraint.
      '';
    };

    minAge = lib.mkOption {
      type = lib.types.str;
      default = "2m";
      description = "Skip files modified more recently than this (avoids copying partial writes).";
    };

    transfers = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = "Parallel transfers; also used for --sftp-concurrency.";
    };

    checkers = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Parallel existence checks.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.offbox-sync = {
      serviceConfig = {
        Label = "com.offbox.sync";
        ProgramArguments = [ "${runner}" ];
        StartInterval = cfg.intervalSeconds;
        RunAtLoad = true;
        StandardOutPath = "/Users/${cfg.user}/Library/Logs/offbox-sync/agent.log";
        StandardErrorPath = "/Users/${cfg.user}/Library/Logs/offbox-sync/agent.err";
      };
    };
  };
}
