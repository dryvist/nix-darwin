# Shared darwin (system-level) configuration
#
# Imported by every host's default.nix. Holds host-agnostic system config and
# consumes registry parameters (networking.hostName, OrbStack). Inference hosts
# (those that declare `mlx` in the registry) also get the shared vllm-mlx Cribl
# log-shipping pipeline (./cribl.nix) — it is identical across machines.
# Host-specific system config — streamline-login lists, energy /
# appleSiliconTunables values — stays in hosts/<label>/default.nix.

{
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

  # Workstations keep macOS' automatic timezone behavior. Server hosts pin UTC
  # so the Friday 00:00 launchd schedule lands at Friday 00:00 UTC there.
  time.timeZone = if hostConfig.isServer then "UTC" else null;

  # SSH/Remote Login — macOS Remote Login via launchd (Settings > General > Sharing).
  services.openssh.enable = true;

  programs = {
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

    # Per-AI-CLI log directories (~/Library/Logs/<cli>/), newsyslog rotation,
    # and opt-in `<cli>-logged` session-capture wrappers. All hosts: the dirs
    # and rotation are harmless where a CLI is absent; the Cribl Edge file
    # inputs that tail them (./cribl.nix) stay gated on `hostConfig ? mlx`.
    ai-cli-log-shipping = {
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
    nixDarwinAutoUpgrade.enable = true; # Friday 00:00 local-time launchd target; server hosts are pinned to UTC above.
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
