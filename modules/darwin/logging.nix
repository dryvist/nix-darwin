# macOS local log configuration + firewall log capture
#
# History: this module used to forward ALL of syslogd's traffic to the
# homelab LB via BSD /etc/syslog.conf remote rules. That path is retired at
# the source: BSD syslogd emits RFC3164 (no year, no timezone), and this Mac
# deliberately stays on local time while every other estate host logs UTC —
# so every forwarded line landed hours-skewed, and it landed on the unifi
# syslog family port (wrong index). Structured Mac telemetry ships through
# the local Cribl Edge instead (hosts/common/cribl.nix), whose sources carry
# absolute, TZ-qualified timestamps.
#
# What remains here:
#   1. /etc/syslog.conf with the stock local rules only (keeps the file
#      nix-managed so activation stays deterministic).
#   2. Firewall log capture: a LaunchDaemon tails the unified log for
#      firewall subsystems (application firewall / network extension /
#      packet filter) in ndjson and appends to a rotated file that the
#      Cribl Edge ships to index=firewall. ULS ndjson timestamps are
#      absolute with a UTC offset, so local time on the Mac is skew-safe.
#      NOTE: raw pf packet logging (pflog0) is NOT captured — macOS ships no
#      pflogd and the default pf ruleset has no `log` rules; adding those is
#      a deliberate security-engineering change, not log plumbing.

{ lib, ... }:

let
  userConfig = import ../../lib/user-config.nix;

  logDir = "${userConfig.user.homeDir}/Library/Logs/firewall";
  logFile = "${logDir}/firewall.log";

  # Firewall-only ULS predicate: application firewall (alf), the network
  # extension filter that backs it on modern macOS, socketfilterfw itself,
  # and pf's own subsystem. Broad within "firewall", nothing else.
  predicate = lib.concatStringsSep " OR " [
    ''subsystem == "com.apple.alf"''
    ''process == "socketfilterfw"''
    ''(subsystem == "com.apple.networkextension" AND category CONTAINS[c] "firewall")''
    ''subsystem == "com.apple.pf"''
  ];
in
{
  # Auto-rename syslog.conf if it has unrecognized content (runs before etc check)
  # This prevents "Unexpected files in /etc" errors during darwin-rebuild
  # See: https://github.com/nix-darwin/nix-darwin/issues/149
  system.activationScripts.preActivation.text = lib.mkBefore ''
    if [[ -f /etc/syslog.conf ]] && [[ ! -L /etc/syslog.conf ]]; then
      # File exists and is not a symlink - check if it's nix-managed
      if ! grep -q "Managed by nix-darwin" /etc/syslog.conf 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Backing up /etc/syslog.conf to /etc/syslog.conf.before-nix-darwin"
        /bin/mv /etc/syslog.conf /etc/syslog.conf.before-nix-darwin
      fi
    fi
  '';

  # Stock local rules only — no remote forwarding (see header).
  environment.etc."syslog.conf".text = ''
    # macOS Syslog Configuration
    # Managed by nix-darwin - do not edit manually
    #
    # Local logging only. Remote shipping is handled by Cribl Edge
    # (hosts/common/cribl.nix), never by syslogd remote rules.

    *.notice;authpriv,remoteauth,ftp,install,internal.none	/var/log/system.log
    auth,authpriv.*;remoteauth.crit			/var/log/system.log
    mail.*						/var/log/mail.log
    install.*					/var/log/install.log
  '';

  # Firewall log capture daemon. Runs as the login user (an admin — ULS
  # firewall entries are readable) so the output file is user-owned and the
  # user-run Cribl Edge can tail it. The startup marker line proves the
  # file -> Edge -> Stream -> Splunk path end-to-end on every daemon start,
  # even while the firewall itself has nothing to say.
  launchd.daemons.firewall-log-shipping = {
    serviceConfig = {
      Label = "com.${userConfig.user.name}.firewall-log-shipping";
      UserName = userConfig.user.name;
      RunAtLoad = true;
      KeepAlive = true;
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          printf '{"eventMessage":"firewall-log-shipping daemon started","subsystem":"local.firewall-log-shipping","timestamp":"%s"}\n' "$(date '+%Y-%m-%d %H:%M:%S%z')"
          exec /usr/bin/log stream --style ndjson --predicate '${predicate}'
        ''
      ];
      StandardOutPath = logFile;
      StandardErrorPath = "${logDir}/firewall-log-shipping.err.log";
    };
  };

  # This daemon's plist is labelled com.<user>.* so launchd-bootstrap.nix's
  # org.nixos.*/com.nix-darwin.* glob never sees it; register it for self-heal
  # so a penalty-boxed instance is reloaded after each activation.
  # See modules/darwin/launchd-self-heal.nix + docs/LAUNCHD-SELF-HEAL.md.
  services.launchdSelfHeal.labels = [ "com.${userConfig.user.name}.firewall-log-shipping" ];

  # User-owned log dir (same pattern as ai-cli-log-shipping.nix: install -d
  # so a root-created parent never blocks the user's writes).
  #
  # Also HUP syslogd: environment.etc swaps the symlink but never signals the
  # daemon, so without this the previous /etc/syslog.conf (including the
  # retired remote-forward rule) keeps running from memory until reboot.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/install -d -o ${userConfig.user.name} -g staff "${logDir}"
    /usr/bin/pkill -HUP syslogd 2>/dev/null || true
  '';

  # Rotate via the system newsyslog run. Flags per ai-cli-logs.conf: G glob,
  # J bzip2, B no rotation banner injected into files Cribl Edge tails,
  # N no syslogd signal.
  environment.etc."newsyslog.d/firewall-logs.conf".text = ''
    # logfilename [owner:group] mode count size when flags
    ${logDir}/*.log ${userConfig.user.name}:staff 640 3 1024 * BGJN
  '';
}
