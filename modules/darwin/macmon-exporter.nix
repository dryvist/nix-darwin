# macmon Prometheus exporter — CPU/GPU/ANE power, temperature, and memory
# metrics for a LAN scraper (the homelab wall), sudoless.
#
# nixpkgs (pinned nixpkgs-26.05-darwin) carries macmon 0.6.1, which predates
# the `serve` subcommand (Prometheus /metrics + JSON /json over HTTP, added
# upstream 0.7.0). Built here from the macmon-src flake input instead —
# pinned by release tag in flake.nix, bumped by renovate.json5's macmon-tag
# customManager (see its comment for why the plain `nix` manager can't) —
# against its own Cargo.lock, so no hand-computed cargoHash lives in this
# repo. version is read from that same source, never duplicated as a literal.
#
# macmon's own `serve --install` writes an imperative plist outside
# nix-darwin's generation management; this module declares the same
# ProgramArguments as a nix-darwin launchd user agent instead, so it is
# torn down/rebuilt like every other generation-managed service.
{
  lib,
  config,
  pkgs,
  macmon-src,
  ...
}:

let
  cfg = config.programs.macmon-exporter;
  cargoToml = fromTOML (builtins.readFile "${macmon-src}/Cargo.toml");

  macmon = pkgs.rustPlatform.buildRustPackage {
    pname = "macmon";
    version = cargoToml.package.version;
    src = macmon-src;
    cargoLock.lockFile = "${macmon-src}/Cargo.lock";
    meta = {
      description = "Sudoless performance monitoring for Apple Silicon processors";
      homepage = "https://github.com/vladkens/macmon";
      license = lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
      mainProgram = "macmon";
    };
  };

  userConfig = import ../../lib/user-config.nix;
  logDir = "${userConfig.user.homeDir}/Library/Logs/macmon-exporter";
in
{
  options.programs.macmon-exporter = {
    enable = lib.mkEnableOption "macmon Prometheus exporter (CPU/GPU/ANE power, temperature, memory) for LAN scraping";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Port macmon's `serve` subcommand listens on (Prometheus text format at /metrics, JSON at /json). macmon's own default.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.macmon-exporter.serviceConfig = {
      Label = "com.nix-darwin.macmon-exporter";
      ProgramArguments = [
        (lib.getExe macmon)
        "serve"
        "--port"
        (toString cfg.port)
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/macmon-exporter.log";
      StandardErrorPath = "${logDir}/macmon-exporter.log";
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o ${userConfig.user.name} -g staff "${logDir}"
    '';

    # The pf anchor (pf-hardening.nix) default-denies inbound except SSH and
    # the cluster link network — without this, macmon binds fine locally but
    # a LAN scrape is silently dropped at the packet filter, never reaching
    # or being refused by macmon itself.
    security.pf.allowedTcpPorts = [ cfg.port ];
  };
}
