# Per-CLI AI Log Capture (directories + rotation + opt-in wrappers)
#
# One log home per AI coding CLI under ~/Library/Logs/<cli>/, rotated by the
# system newsyslog run — the local half of the per-CLI Cribl Edge shipping
# pipeline (hosts/common/cribl.nix tails each directory into its own tcpjson
# output/service port). Uses launchd logs + /etc/newsyslog.d rotation and
# nix-ai's fabric launchd module as the operational model.
#
# Capture mechanism per CLI — deliberately conservative. These are
# INTERACTIVE tools (TUIs and a GUI), not services: wrapping them in a
# launchd agent or redirecting their stdio would break them, so no daemon is
# invented here.
#
#   codex / agy / copilot — full-screen TUIs. Their stdout is the UI, so a
#     plain `>>` redirect is useless AND breaks the TTY. Feasible capture is
#     the opt-in `<cli>-logged` wrapper below: /usr/bin/script keeps a real
#     pty (the TUI behaves normally) while appending the whole session
#     typescript to ~/Library/Logs/<cli>/<cli>.log. ANSI sequences ride
#     along; stripping is a Stream-side pipeline concern, not a capture
#     concern. Structured logs (e.g. codex's own file logging under
#     ~/.codex/log/) can additionally be pointed at this directory via the
#     CLI's own configuration — that population is owned by the CLI config
#     (nix-ai), not this module.
#
#   vscode — a GUI app; the `code` launcher detaches immediately, so there is
#     nothing to wrap. The directory + rotation are still managed here; the
#     files are populated by VS Code's own logging configuration (its native
#     logs live under ~/Library/Application Support/Code/logs — point or copy
#     the interesting channels here via user settings/tasks).
#
# Rotation uses a newsyslog glob (G flag) per directory so any additional
# file a CLI's own config drops into its directory is rotated too — matching
# the `*.log` glob the Edge file inputs tail.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.ai-cli-log-shipping;
  homeDir = "/Users/${cfg.user}";
  logRoot = "${homeDir}/Library/Logs";

  # cli name -> whether an interactive pty wrapper is feasible (see header).
  clis = {
    codex = {
      wrap = true;
    };
    agy = {
      wrap = true;
    };
    copilot = {
      wrap = true;
    };
    vscode = {
      wrap = false;
    };
  };

  wrappedClis = lib.attrNames (lib.filterAttrs (_: c: c.wrap) clis);

  # Opt-in session capture: `codex-logged ...` runs codex on a real pty via
  # /usr/bin/script, appending the typescript to the CLI's log file. The bare
  # CLI name stays untouched — interactive use is never wrapped implicitly.
  mkWrapper =
    name:
    pkgs.writeShellScriptBin "${name}-logged" ''
      if ! command -v ${name} >/dev/null 2>&1; then
        echo "Error: ${name} is not installed or not in PATH" >&2
        exit 127
      fi
      exec /usr/bin/script -q -a "${logRoot}/${name}/${name}.log" ${name} "$@"
    '';
in
{
  options.programs.ai-cli-log-shipping = {
    enable = lib.mkEnableOption "per-AI-CLI log directories, newsyslog rotation, and opt-in session-capture wrappers";

    user = lib.mkOption {
      type = lib.types.str;
      description = "macOS login user that owns the log directories (rotation re-creates files with this ownership).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = map mkWrapper wrappedClis;

    # Create each log dir with user ownership (install -d would otherwise
    # leave missing parents root-owned, blocking the user's log writes).
    system.activationScripts.postActivation.text = lib.concatMapStrings (name: ''
      /usr/bin/install -d -o ${cfg.user} -g staff "${logRoot}/${name}"
    '') (lib.attrNames clis);

    # Rotate via the system newsyslog run (reads /etc/newsyslog.d/*.conf on
    # macOS). G = the path is a glob; J = bzip2 the rotated file; B = binary
    # (no plain-text rotation message injected into logs Cribl Edge tails);
    # N = no signal to syslogd (these files aren't syslogd-written). Mode 600:
    # session transcripts carry prompts, code, and potentially tokens.
    environment.etc."newsyslog.d/ai-cli-logs.conf".text =
      lib.concatStringsSep "\n" (
        [ "# logfilename [owner:group] mode count size when flags" ]
        ++ map (name: "${logRoot}/${name}/*.log ${cfg.user}:staff 600 3 1024 * BGJN") (lib.attrNames clis)
      )
      + "\n";
  };
}
