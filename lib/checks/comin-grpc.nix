# comin's control socket group, read from the YAML comin is started with: it must be `wheel`, a
# group macOS ships. comin's upstream default, `users`, does not exist on macOS, and its control
# server then fails to start.
{ pkgs, studio }:
let
  inherit (pkgs) lib;
  cfg =
    (studio.extendModules {
      modules = [
        {
          services.cominGitOps = {
            enable = true;
            remoteUrl = "https://example.invalid/repo.git";
            accessTokenPath = "/var/db/example-token";
          };
        }
      ];
    }).config;
  # `comin run --config <yaml>`: the YAML is the last argument.
  configYaml = lib.last (lib.splitString " " cfg.launchd.daemons.comin.command);
in
pkgs.runCommand "check-comin-grpc" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
  group=$(yq '.grpc.unix_socket_group' ${configYaml})
  [ "$group" = wheel ] || {
    echo "comin grpc.unix_socket_group is '$group', expected wheel" >&2
    exit 1
  }
  touch $out
''
