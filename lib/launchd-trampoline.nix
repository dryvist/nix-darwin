{ lib, pkgs }:

let
  scriptText = ''
    #!/bin/sh
    /bin/wait4path /nix/store && exec "$@"
  '';
  script = pkgs.writeText "launchd-trampoline" scriptText;
in
{
  inherit scriptText;

  systemDirectory = "/usr/local/libexec/launchd-trampolines";
  homeDirectory = home: "${home}/Library/Application Support/launchd-trampolines";

  programArguments =
    directory: name: arguments:
    [ "${directory}/${name}" ] ++ arguments;

  install =
    {
      directory,
      names,
      owner ? null,
    }:
    let
      ownerArgs =
        if owner == null then
          ""
        else
          "-o ${lib.escapeShellArg owner.user} -g ${lib.escapeShellArg owner.group}";

      cleanup =
        if names == [ ] then
          ''/bin/rm -f "$path"''
        else
          ''
            case "$name" in
              ${lib.concatStringsSep "|" (map lib.escapeShellArg names)}) ;;
              *) /bin/rm -f "$path" ;;
            esac
          '';
    in
    ''
      /usr/bin/install -d ${ownerArgs} -m 0755 ${lib.escapeShellArg directory}
      ${lib.concatMapStringsSep "\n" (
        name:
        "/usr/bin/install ${ownerArgs} -m 0755 ${lib.escapeShellArg (toString script)} ${lib.escapeShellArg "${directory}/${name}"}"
      ) names}
      for path in ${lib.escapeShellArg directory}/*; do
        [ -f "$path" ] || [ -L "$path" ] || continue
        name=''${path##*/}
        ${cleanup}
      done
    '';
}
