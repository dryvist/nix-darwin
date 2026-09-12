# Remove user LaunchAgents this configuration no longer declares.
#
# nix-darwin's own reconcile only removes a user agent that was present in the
# PREVIOUS generation and is absent from the new one. An agent orphaned any
# earlier — its module deleted while that switch's removal step did not take
# effect — stays registered forever, pointing at a store path GC has since
# collected, and `launchctl list` shows it parked on EX_CONFIG across every
# later activation.
#
# This pass compares the live directory against the generation instead: any
# `com.nix-darwin.*` plist in the primary user's ~/Library/LaunchAgents that
# the generation does not ship is booted out and deleted. Only that prefix is
# touched; plists from other sources are left alone.
#
# Activation-script constraints obeyed here: docs/ACTIVATION-SCRIPTS-RULES.md

{ config, lib, ... }:

let
  userConfig = import ../../lib/user-config.nix;
  user = userConfig.user.name;
  home = userConfig.user.homeDir;
in
{
  # postActivation + mkAfter: after nix-darwin's own launchd reconcile.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    for plist in ${home}/Library/LaunchAgents/com.nix-darwin.*.plist; do
      [ -f "$plist" ] || continue
      name=$(basename "$plist")
      if [ ! -e "${config.system.build.launchd}/user/Library/LaunchAgents/$name" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Removing orphaned user agent ''${name%.plist}"
        /bin/launchctl bootout "gui/$(id -u ${user})/''${name%.plist}" 2>/dev/null || true
        sudo --user=${user} -- rm -f "$plist" \
          || echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Could not remove $plist" >&2
      fi
    done
  '';
}
