# Rotation for the local AI serving stack's logs under ~/Library/Logs/<service>/.
#
# WHY THIS IS A SYSTEM MODULE AND NOT A USER LaunchAgent
#
# nix-ai previously rotated these from home-manager: a per-service
# `~/.config/newsyslog.d/<svc>.conf` plus an hourly user LaunchAgent running
# `/usr/sbin/newsyslog -f <that conf>`. It never worked. `newsyslog` refuses to
# run as anyone but root — the check is in the binary, before it reads a config
# or touches a file, so `newsyslog -n` (pure dry-run) fails too:
#
#     $ /usr/sbin/newsyslog -n -f ~/.config/newsyslog.d/mlx-model-server.conf
#     newsyslog: must have root privs
#
# Both agents therefore sat at exit status 1 every hour while server.log grew
# past 40 MB unbounded. The old comment blamed the config LOCATION ("stock
# newsyslog only reads /etc/newsyslog.d/, which requires root, so use a
# user-level config") — but the privilege belongs to the binary, not the path,
# so moving the config never avoided anything.
#
# The fix is the mechanism this estate already uses successfully for user-owned
# logs: an /etc/newsyslog.d/ entry consumed by the SYSTEM newsyslog run, which
# macOS invokes as root on its own schedule. `owner:group` keeps the rotated
# files user-owned. Proven here already by logging.nix (firewall) and
# ai-cli-log-shipping.nix, both of which rotate ~/Library/Logs paths.
#
# Flags match those two: G glob, J bzip2, B no rotation banner injected into
# files Cribl Edge tails, N no signal to syslogd (nothing here is syslogd-written).
{
  lib,
  config,
  ...
}:

let
  cfg = config.programs.agent-log-rotation;
in
{
  options.programs.agent-log-rotation = {
    enable = lib.mkEnableOption "newsyslog rotation for the local AI serving stack's user logs";

    user = lib.mkOption {
      type = lib.types.str;
      description = "Owner of the log files; rotated files are chowned back to them.";
    };

    directories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "mlx-model-server"
        "mlx-cluster"
        "fabric"
        # Listed while the engine is stopped, on purpose. Its own rotation was
        # removed with the engine, leaving an 86 MB orphan log; a glob ages that
        # out with no one-off delete to remember, and the path is already right
        # when vllm-mlx comes back after the soak.
        "vllm-mlx"
      ];
      description = ''
        Directory names under ~/Library/Logs to rotate. One `*.log` glob per
        entry, so `server.log` and `server.error.log` are both covered and a new
        log file needs no change here. A directory that does not exist is
        skipped by newsyslog, so listing one for a service this host does not
        run is harmless.
      '';
    };

    # Single definition of each tunable. The three nix-ai configs this replaces
    # each hardcoded their own copy of both numbers.
    keep = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 3;
      description = "Compressed archives retained per log file.";
    };

    maxSizeKB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10240;
      description = "Rotate once a log exceeds this size, in KB.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."newsyslog.d/agent-logs.conf".text =
      lib.concatStringsSep "\n" (
        [ "# logfilename [owner:group] mode count size when flags" ]
        ++ map (
          name:
          "/Users/${cfg.user}/Library/Logs/${name}/*.log ${cfg.user}:staff 644 "
          + "${toString cfg.keep} ${toString cfg.maxSizeKB} * BGJN"
        ) cfg.directories
      )
      + "\n";
  };
}
