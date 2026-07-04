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

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-keychain;
  userConfig = import ../../lib/user-config.nix;
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
    # missing parents root-owned, blocking the user agent's log writes).
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -o ${userConfig.user.name} -g staff "${logDir}"

      # Root reads the sops-decrypted password itself and passes it through
      # as a one-shot env var on the sudo command line — it never touches a
      # user-readable file. Keychains are per-user, so the setup script must
      # actually run AS the login user, not root. A prefix assignment
      # (`VAR=val cmd ...`) is NOT visible when expanding later words on the
      # same command line — verified empirically — so this must be a real
      # assignment on its own line before the sudo invocation references it.
      OPENBAO_KEYCHAIN_PASSWORD="$(cat ${config.sops.secrets."OPENBAO_KEYCHAIN_PASSWORD".path})"
      /usr/bin/sudo -u ${userConfig.user.name} \
        env OPENBAO_KEYCHAIN_PASSWORD="$OPENBAO_KEYCHAIN_PASSWORD" \
        ${lib.getExe setupScript} ${keychainPath}
    '';

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
