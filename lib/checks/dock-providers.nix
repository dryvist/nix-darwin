# Dock apps are tied to the provider that installs them.
#
# Dock entries (modules/darwin/dock/persistent-apps.nix) name their provider,
# and an assertion in that module checks the provider is declared on the host
# and installs to the entry's path. `system-eval` forces those assertions for
# every host. This check covers what it cannot:
#
#   - the contract itself: each failure mode must be detected, so the rule
#     cannot quietly stop catching anything (for example a nixpkgs app whose
#     Dock path is still under /Applications);
#   - the guard is present on every host, so a host cannot drop it by not
#     importing the module.
#
# Pass the REAL evaluated host configurations: `lib/checks.nix` receives
# `darwinConfigurations = { }`, so a check placed there would pass vacuously.
{ pkgs, configs }:
let
  inherit (pkgs) lib;
  dockApps = import ../dock-apps.nix { inherit lib; };

  homeDir = "/Users/test";
  hmApps = "${homeDir}/Applications/Home Manager Apps";
  declared = {
    inherit homeDir;
    casks = [ "slack" ];
    masIds = [ 1 ];
    pnames = [ "obsidian" ];
  };

  good = [
    {
      path = "/System/Applications/Clock.app";
      via = {
        system = true;
      };
    }
    {
      path = "/Applications/Slack.app";
      via = {
        cask = "slack";
      };
    }
    {
      path = "/Applications/Omi.app";
      via = {
        mas = 1;
      };
    }
    {
      path = "${hmApps}/Obsidian.app";
      via = {
        nixpkgs = "obsidian";
      };
    }
    {
      path = "/Applications/Vendor.app";
      via = {
        manual = "vendor download";
      };
    }
  ];

  # One entry per failure mode; each must produce a problem.
  bad = {
    undeclaredCask = {
      path = "/Applications/Gone.app";
      via = {
        cask = "gone";
      };
    };
    caskUnderHomeManagerApps = {
      path = "${hmApps}/Slack.app";
      via = {
        cask = "slack";
      };
    };
    undeclaredMas = {
      path = "/Applications/Gone.app";
      via = {
        mas = 2;
      };
    };
    undeclaredNixpkgs = {
      path = "${hmApps}/Gone.app";
      via = {
        nixpkgs = "gone";
      };
    };
    nixpkgsAppStillUnderApplications = {
      path = "/Applications/Obsidian.app";
      via = {
        nixpkgs = "obsidian";
      };
    };
    manualWithoutReason = {
      path = "/Applications/Vendor.app";
      via = {
        manual = "";
      };
    };
    systemNotTrue = {
      path = "/System/Applications/Clock.app";
      via = {
        system = false;
      };
    };
    noProvider = {
      path = "/Applications/Vendor.app";
      via = { };
    };
    twoProviders = {
      path = "/Applications/Slack.app";
      via = {
        cask = "slack";
        mas = 1;
      };
    };
  };

  missed = builtins.filter (name: dockApps.problems declared [ bad.${name} ] == [ ]) (
    builtins.attrNames bad
  );

  hostsWithoutGuard = builtins.attrNames (
    lib.filterAttrs (
      _: cfg: !builtins.any (a: lib.hasPrefix "dock-apps:" a.message) cfg.config.assertions
    ) configs
  );
in
assert
  dockApps.problems declared good == [ ]
  || throw ''
    dock-providers: a valid Dock entry set was rejected:
    ${lib.concatStringsSep "\n" (dockApps.problems declared good)}
  '';
assert
  missed == [ ]
  || throw ''
    dock-providers: lib/dock-apps.nix no longer detects these failure modes:
    ${lib.concatStringsSep "\n" missed}
  '';
assert
  hostsWithoutGuard == [ ]
  || throw ''
    dock-providers: these hosts do not carry the Dock provider assertion; import
    modules/darwin/dock/persistent-apps.nix on them:
    ${lib.concatStringsSep "\n" hostsWithoutGuard}
  '';
pkgs.runCommand "check-dock-providers" { } ''
  echo "every Dock failure mode is detected, and every darwin host carries the Dock provider assertion"
  touch $out
''
