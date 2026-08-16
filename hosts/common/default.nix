# Shared darwin (system-level) configuration
#
# Imported by every host's default.nix. Holds host-agnostic system config and
# consumes registry parameters (networking.hostName, OrbStack). Inference hosts
# (those that declare `mlx` in the registry) also get the shared MLX model-server Cribl
# log-shipping pipeline (./cribl.nix) — it is identical across machines.
# Host-specific system config — streamline-login lists, energy /
# appleSiliconTunables values — stays in hosts/<label>/default.nix.

{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}:

let
  userConfig = import ../../lib/user-config.nix;
in
{
  imports = [
    # Darwin system modules
    ../../modules/darwin/common.nix
    # Cribl Edge/Stream log shipping (self-gated on `hostConfig ? mlx`).
    ./cribl.nix
    ./cribl-stream-local.nix
  ];

  # Network hostname from the per-host registry.
  networking.hostName = hostConfig.hostName;

  # Workstations keep macOS' automatic timezone behavior. Server hosts pin GMT
  # (UTC-equivalent, no DST) so the Friday 00:00 launchd schedule lands at 00:00
  # there. macOS `systemsetup -settimezone` rejects bare "UTC" (not in its
  # listtimezones); "GMT" is the accepted +00:00 value.
  time.timeZone = if hostConfig.isServer then "GMT" else null;

  services = {
    # SSH/Remote Login — macOS Remote Login via launchd (Settings > General > Sharing).
    openssh.enable = true;

    # Both hosts are cluster-mode nodes, so both announce their own maintenance
    # window while a rank is live and close it at teardown. Enabled here rather
    # than per host for the same reason clusterLinkPrep is: the pair is
    # symmetric, and a window that only one side of a cluster opens is worse
    # than none.
    clusterMaintenanceWindow = {
      enable = true;
      projectId = 54;
    };
  };

  # Screen Sharing (VNC) — macOS Remote Login's GUI counterpart, enabled on
  # every host so a reboot always leaves remote recovery available without a
  # trip to the physical console. See modules/darwin/apps/screen-sharing.nix.
  programs.screenSharing.enable = true;

  # Application firewall on every host. The MBP had this enabled by hand; the
  # Studio shipped disabled, which left the firewall-log-shipping feed with
  # nothing to say (its `log stream` daemon was alive but the ALF subsystem
  # was silent). allowSigned/allowSignedApp match the working MBP posture so
  # LAN services (sshd, llama-swap via signed python) keep accepting inbound.
  networking.applicationFirewall = {
    enable = true;
    allowSigned = true;
    allowSignedApp = true;
    blockAllIncoming = false;
    enableStealthMode = false;
  };

  programs = {
    # Login-time resume of an armed Claude Code mission after a reboot.
    claude-continuity = {
      enable = true;
      user = userConfig.user.name;
    };

    # Custom file extensions recognized as tar.gz archives (Finder auto-extract
    # + shell autocomplete).
    file-extensions.enable = true;

    # --- OrbStack ---
    # Container runtime as a system-level application on a dedicated APFS volume.
    # Only configured when the host enables it (headless hosts may not).
    # package.enable = false: OrbStack is installed via Homebrew cask (greedy) in
    # modules/darwin/homebrew.nix — a real /Applications copy, so TCC permissions
    # (Docker socket, Linux VM) persist across darwin-rebuild rather than breaking
    # on every /nix/store path change.
    # background.enable = false: `orb start` exits 0 in <1s; KeepAlive=true was
    # throttle-respawning it into a runningboardd assertion flood. OrbStack.app
    # manages its own startup.
    # `enable or false` tolerates a host that omits `orbstack` entirely.
    orbstack = lib.mkIf (hostConfig.orbstack.enable or false) {
      enable = true;
      package.enable = false;
      background.enable = false;
    };

    # Dedicated APFS volumes for logical data separation (AI model caches,
    # container data). Created identically on every host that declares them in
    # lib/hosts.nix — no quota, logical partitions sharing the container's free
    # space. See modules/darwin/apps/apfs-volumes.nix.
    apfsVolumes = lib.mkIf (hostConfig ? apfsVolumes) {
      enable = true;
      inherit (hostConfig) apfsContainer;
      volumes = hostConfig.apfsVolumes;
    };

    # Dedicated 100 GiB-quota "git" APFS volume on every Mac. The container is
    # resolved at runtime (no disk id hardcoded); create-if-absent, no data
    # migration. See modules/darwin/apps/git-apfs-volume.nix.
    gitApfsVolume.enable = true;

    # Per-AI-CLI log directories (~/Library/Logs/<cli>/), newsyslog rotation,
    # and opt-in `<cli>-logged` session-capture wrappers. All hosts: the dirs
    # and rotation are harmless where a CLI is absent; the Cribl Edge file
    # inputs that tail them (./cribl.nix) stay gated on `hostConfig ? mlx`.
    ai-cli-log-shipping = {
      enable = true;
      user = userConfig.user.name;
    };

    # Rotation for the AI serving stack's logs (~/Library/Logs/<service>/), via
    # the root-run system newsyslog. Replaces three user LaunchAgents in nix-ai
    # that could never work — `newsyslog` requires root, so they sat at exit 1
    # while the logs grew unbounded. All hosts: a directory for a service this
    # host does not run is simply skipped.
    agent-log-rotation = {
      enable = true;
      user = userConfig.user.name;
    };
  };

  system = {
    # --- Remove unused Apple iWork/iLife apps (all hosts) ---
    # There is no declarative nix primitive to remove a macOS-preinstalled app:
    # nix is additive, and `homebrew.onActivation.cleanup = "zap"` provably leaves
    # them (verified on jevans-ms). nix-darwin's native activation interface is the
    # declarative way to express "these must not exist". Globs cover Apple's macOS
    # 26 display-name variants (e.g. "Keynote Creator Studio.app"); the removal
    # runs as root at activation and `rm -rf` is idempotent.
    activationScripts.postActivation.text = lib.mkAfter ''
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Removing unused Apple iWork/iLife apps from /Applications..."
      rm -rf /Applications/Keynote*.app /Applications/Numbers*.app /Applications/Pages*.app /Applications/GarageBand*.app /Applications/iMovie*.app
    '';

    # --- Class-driven system defaults (server class only) ---
    # `class = "server"` (headless machines) flips a few macOS system knobs away
    # from the laptop-oriented module defaults. `mkDefault` so an explicit host
    # value still wins. `mkIf isServer` gates each: a workstation needs nothing —
    # the module defaults already match the laptop.
    # Both hosts are cluster-mode nodes: keep every RDMA-capable Thunderbolt
    # port out of bridge0 and converge the role link address onto whichever
    # port the cable is in. Read from hostConfig.mlx.clusterMode.role (the same
    # field nix-ai's programs.mlx.clusterMode.role is spliced from — see
    # hosts/common/cluster-quiesce.nix's identical `hostConfig.mlx.clusterMode.role
    # or null` read) rather than re-deriving from isServer: they coincided only
    # by accident of machine class, and deriving role here from a DIFFERENT
    # source than the one nix-ai's rank env reads let this pin the Thunderbolt
    # static IPs to the wrong Mac the moment anyone changed just one of the two.
    # Attribute-existence gate (repo convention, matches cluster-quiesce.nix):
    # non-inference hosts have no `mlx` at all, so a bare `hostConfig.mlx.…`
    # read would crash eval on them.
    clusterLinkPrep = lib.mkIf (hostConfig ? mlx && hostConfig.mlx ? clusterMode) {
      enable = true;
      role = hostConfig.mlx.clusterMode.role;
      # Clustered wired ceilings, applied around rank start/stop by the cluster
      # watcher (standalone value restored at link-down). Raised 2026-07-19 per
      # user decision: the old 90000/80000 caps were low enough to force swap
      # thrash under the per-rank shard, and swap saturation kills the whole
      # cluster just as surely as a wired-out WindowServer — so an ultra-low
      # cap bought nothing. Headroom over conservatism; the operative guard
      # against thrash is now the detach exit-3 stale-swap gate + reboot-first
      # doctrine (INC-17075), not a tiny wired ceiling.
      # The headless coordinator derives the clustered ceiling from the host's
      # standalone wired ceiling (102400 MiB = 100 GiB, maxLocalLlmGb = 100) — it
      # has no GUI working set to protect, so the same reserve that bounds
      # standalone serving is ample in clustered mode too. The GLM-4.7-REAP-50
      # per-rank shard (~49 GB + KV + buffer ~65 GB) leaves ~35 GB slack.
      #
      # The MacBook worker is a workstation: WindowServer and the rest of the
      # GUI working set must stay unwirable even while a shard is loaded, which
      # is the exact starvation the 2026-07-12 panic hit (INC-17076). cluster-
      # quiesce quits the GUI and boots out agents at link-up, but the ceiling
      # itself is the last-resort guard, so it is sized below the standalone
      # value rather than equal to it.
      clusterWiredLimitMb =
        if hostConfig.isServer then config.system.appleSiliconTunables.wiredLimitMb else 90000;
    };
    energy.wakeOnMagicPacket = lib.mkIf hostConfig.isServer (lib.mkDefault true); # Wake-on-LAN for a headless box
    networkTuning.enable = lib.mkIf hostConfig.isServer (lib.mkDefault true); # socket buffers for LAN serving
    appleSiliconTunables.energyMode = lib.mkIf hostConfig.isServer (lib.mkDefault "unmanaged"); # no High Power Mode on a desktop
  };

  # SSH sessions arrive from the workstation's Ghostty terminal; without its
  # terminfo the remote zsh init spews "can't find terminal definition for
  # xterm-ghostty" on every login. Workstations get the entry from the app
  # itself; headless hosts ship just the terminfo output.
  environment.systemPackages = lib.optionals hostConfig.isServer [ pkgs.ghostty-bin.terminfo ];
}
