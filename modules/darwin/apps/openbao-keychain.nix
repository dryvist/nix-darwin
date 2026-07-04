# OpenBao keychain-backed secret-zero
#
# Creates a dedicated `openbao.keychain-db` macOS keychain (separate from the
# `automation.keychain-db`/`elevate-access.keychain-db` GitHub-token keychains)
# with a 72-hour auto-lock. The KEYCHAIN'S LOCK STATE is the entire access
# boundary for OpenBao AppRole credentials stored in it — not the AppRole's
# own TTL (see terraform-proxmox docs/SECRETS_HIERARCHY.md). Once unlocked
# (one password prompt every ~3 days), a launchd user agent reads each
# domain's role_id/secret_id from it and publishes them into the login
# session's launchd environment via `launchctl setenv`, so any subsequently
# spawned process (a terminal, an ansible-playbook run) inherits them
# ambiently — no keychain access required in the consuming process itself.
#
# This module only creates the empty keychain and installs the resolver
# agent — it does NOT seed any credentials. Loading each domain's role_id/
# secret_id into it (via `security add-generic-password`) is a manual,
# one-time operator step performed once the live OpenBao cluster's RBAC
# actually mints those AppRoles.
#
# Neither of the two existing keychains is Nix-managed today (both were
# created by hand, passwords never stored anywhere) — this is the first
# Nix-managed keychain in this repo. Its own unlock password IS sops-managed
# (secrets/openbao-keychain.yaml), a deliberate new precedent: unlike the
# AppRole credentials it will hold, the keychain's own password isn't
# something a human needs to type routinely, so there's no reason to keep it
# purely tribal knowledge.
#
# Both keychain setup and the resolver run as NATIVE user-domain LaunchAgents
# — confirmed on real hardware that a root-run activation script trying to
# reach across into the login user's securityd session (via `sudo -u` or
# `launchctl asuser`) creates the keychain FILE fine but silently fails to
# persist the keychain SEARCH-LIST update, a session-scoped operation. A
# genuine user LaunchAgent needs no privilege crossing at all. This is why
# the keychain's own unlock password is `userOnly` in sops.nix rather than
# `rootOnly` — the setup agent reads it directly with its own permissions.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-keychain;
  userConfig = import ../../../lib/user-config.nix;
  homeDir = userConfig.user.homeDir;
  logDir = "${homeDir}/Library/Logs/openbao-keychain-resolver";
  keychainPath = "${homeDir}/Library/Keychains/openbao.keychain-db";

  setupScript = pkgs.writeShellApplication {
    name = "openbao-keychain-setup";
    runtimeInputs = [ ];
    text = builtins.readFile ./../scripts/openbao-keychain-setup.sh;
  };

  resolverScript = pkgs.writeShellApplication {
    name = "openbao-keychain-resolver";
    runtimeInputs = [ ];
    text = builtins.readFile ./../scripts/openbao-keychain-resolver.sh;
  };
in
{
  options.programs.openbao-keychain = {
    enable = lib.mkEnableOption "the dedicated OpenBao keychain + resolver agent";

    resolveIntervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14400; # 4 hours — several refreshes within the 72h window.
      description = ''
        How often the resolver LaunchAgent re-reads the keychain and
        re-publishes env vars via launchctl setenv, in addition to RunAtLoad.
        Catches the keychain being unlocked sometime after login.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Create the log dir with user ownership up front (matches
    # claude-scheduled-jobs.nix's rationale: install -d would otherwise leave
    # missing parents root-owned, blocking the user agents' log writes). This
    # is the ONLY thing that still needs to run as root — keychain setup
    # itself is a native user LaunchAgent below, crossing no privilege
    # boundary at all.
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${userConfig.user.name} -g staff "${logDir}"
    '';

    launchd.user.agents.openbao-keychain-setup.serviceConfig = {
      Label = "com.nix-darwin.openbao-keychain-setup";
      # Confirmed on real hardware: running this from a root-run activation
      # script via sudo/launchctl-asuser crosses into the login user's
      # securityd session incorrectly — the keychain FILE gets created (a
      # plain filesystem op) but the search-list UPDATE (session-scoped)
      # silently never persists, despite the command reporting success. A
      # genuine user LaunchAgent needs no privilege crossing, so it Just
      # Works. Idempotent — safe to (and expected to) run at every login.
      ProgramArguments = [
        (lib.getExe setupScript)
        keychainPath
        config.sops.secrets."OPENBAO_KEYCHAIN_PASSWORD".path
      ];
      RunAtLoad = true;
      ProcessType = "Background";
      StandardOutPath = "${logDir}/setup.log";
      StandardErrorPath = "${logDir}/setup.error.log";
      EnvironmentVariables = {
        HOME = homeDir;
      };
    };

    launchd.user.agents.openbao-keychain-resolver.serviceConfig = {
      Label = "com.nix-darwin.openbao-keychain-resolver";
      ProgramArguments = [ (lib.getExe resolverScript) ];
      RunAtLoad = true;
      StartInterval = cfg.resolveIntervalSeconds;
      ProcessType = "Background";
      StandardOutPath = "${logDir}/resolver.log";
      StandardErrorPath = "${logDir}/resolver.error.log";
      EnvironmentVariables = {
        HOME = homeDir;
      };
    };
  };
}
