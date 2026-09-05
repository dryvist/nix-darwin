# Automation Identity — the `claude` macOS account
#
# Creates the second local account that AI harnesses run under. The account is
# hidden from the login window, sits in `staff` (gid 20) and NOT in `admin`, so
# it holds no `(ALL) ALL` sudo grant and reads the operator's files only where
# they are group-readable. Hiding a path from it is `chmod 700 <path>` by the
# operator — nothing to declare here.
#
# ⚠️ DELETION FOOTGUN: `users.knownUsers` is the list of accounts nix-darwin
# manages. Removing this name from it does not "stop managing" the account —
# the next activation runs `sysadminctl -deleteUser`, which deletes the account
# and, with this repo's home-manager `backupCommand`, its home directory. To
# stop granting the account capabilities while keeping it, remove those grants
# and leave this module in place.
#
# There is no `users.users.<name>.extraGroups` option in nix-darwin.
# Supplementary group membership is declared as `users.groups.<g>.members`.

{ pkgs, ... }:

let
  userConfig = import ../../lib/user-config.nix;
  inherit (userConfig) agentUser;
in
{
  users.knownUsers = [ agentUser.name ];

  users.users.${agentUser.name} = {
    inherit (agentUser) name uid;

    # staff — the operator's primary group, and the whole of the read story.
    gid = 20;

    home = agentUser.homeDir;
    createHome = true;

    # Keep the account off the login window; sessions start with `sudo -u`.
    isHidden = true;

    description = "Automation identity";

    # programs.zsh.enable is already true (modules/darwin/common.nix).
    shell = pkgs.zsh;
  };
}
