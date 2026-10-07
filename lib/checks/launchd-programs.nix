{
  pkgs,
  configs,
  userConfig,
}:

let
  python = pkgs.python3;
  checker = pkgs.writeText "check-launchd-programs.py" ''
    import pathlib
    import plistlib
    import sys

    # Enforce that rendered plists do not use generic interpreters as ProgramArguments[0] or Program.
    GENERIC_NAMES = {"sh", "bash", "zsh", "dash", "env"}
    # These upstream-generated labels are the only interpreter-wrapper exceptions.
    ALLOWLIST_LABEL_PREFIXES = ("org.nixos.", "systems.determinate.")

    def is_generic(program):
        if not isinstance(program, str):
            return False
        name = pathlib.PurePath(program).name.lower()
        return name in GENERIC_NAMES or name.startswith(("python", "node"))

    failed = False
    for root_arg in sys.argv[1:]:
        root = pathlib.Path(root_arg).resolve()
        plists = sorted(root.rglob("*.plist")) if root.is_dir() else []
        if not plists:
            print(f"{root_arg}: no rendered launchd plists to check", file=sys.stderr)
            failed = True
        for path in plists:
            with path.open("rb") as stream:
                plist = plistlib.load(stream)
            label = plist.get("Label", path.stem)
            if label.startswith(ALLOWLIST_LABEL_PREFIXES):
                continue
            candidates = []
            arguments = plist.get("ProgramArguments")
            if isinstance(arguments, list) and arguments:
                candidates.append(arguments[0])
            if "Program" in plist:
                candidates.append(plist["Program"])
            for program in candidates:
                if is_generic(program):
                    print(f"{label}: generic launchd program {program}", file=sys.stderr)
                    failed = True
                    break

    sys.exit(1 if failed else 0)
  '';

  negativeTest =
    pkgs.runCommand "check-launchd-programs-negative"
      {
        nativeBuildInputs = [ python ];
      }
      ''
        mkdir -p fixture
        cat > fixture/bad.plist <<'PLIST'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key><string>test.generic-shell</string>
          <key>ProgramArguments</key>
          <array><string>/bin/sh</string><string>-c</string><string>true</string></array>
        </dict>
        </plist>
        PLIST
        ${python}/bin/python3 - <<'PY'
        import os
        import subprocess
        import sys

        result = subprocess.run(
            ["${python}/bin/python3", "${checker}", os.path.join(os.getcwd(), "fixture")],
            capture_output=True,
            text=True,
            check=False,
        )
        expected = "test.generic-shell: generic launchd program /bin/sh"
        if result.returncode == 0 or expected not in result.stderr:
            print("the rendered launchd program check did not reject the fixture", file=sys.stderr)
            print(result.stdout, result.stderr, file=sys.stderr)
            sys.exit(1)
        PY
        touch "$out"
      '';

  hostChecks = pkgs.lib.mapAttrsToList (
    hostName: darwinConfig:
    let
      cfg =
        (darwinConfig.extendModules {
          modules = [ { services.clusterMaintenanceWindow.passwordSecret = "ci-stub#password"; } ];
        }).config;
      homeGeneration = cfg.home-manager.users.${userConfig.user.name}.home.activationPackage;
      launchd = cfg.system.build.launchd;
    in
    pkgs.runCommand "check-launchd-programs-${hostName}"
      {
        nativeBuildInputs = [ python ];
        inherit homeGeneration launchd;
      }
      ''
        ${python}/bin/python3 ${checker} "$homeGeneration/LaunchAgents" "$launchd"
        touch "$out"
      ''
  ) configs;
in
pkgs.runCommand "check-launchd-programs" { } ''
  ${pkgs.lib.concatMapStringsSep "\n" (check: "test -e ${check}") hostChecks}
  test -e ${negativeTest}
  touch "$out"
''
