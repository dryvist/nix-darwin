# Every host's AI-stack roles resolve, judged against the roles the role map
# assigns to that host's class (hosts/common/role-map.nix).
#
# Positive half: each host's primary Home Manager user evaluates with no failed
# assertion, so every role the class declares compiles into a serving alias.
#
# Negative half: a model the class keeps whose id is empty leaves every role it
# serves unresolved, and nix-ai's "every AI-stack logical role must resolve"
# assertion must fire. A scoping change that stopped checking declared
# roles would pass the positive half and fail this one.
#
# Pass the REAL evaluated host configurations (see cli-ownership.nix for why a
# check fed an empty set passes vacuously).
{
  pkgs,
  configs,
  userConfig,
}:
let
  inherit (pkgs) lib;
  userName = userConfig.user.name;

  failedMessages =
    cfg: lib.concatMapStringsSep "\n" (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions);

  primaryUser = cfg: cfg.config.home-manager.users.${userName};

  # The first model the host class keeps, given an empty id for the negative case.
  broken =
    cfg:
    let
      mlx = (primaryUser cfg).programs.mlx;
      key = lib.head (lib.attrNames mlx.catalog);
    in
    cfg.extendModules {
      modules = [
        {
          home-manager.users.${userName}.programs.mlx.roleMap = lib.mkForce (
            mlx.roleMap
            // {
              models = mlx.roleMap.models // {
                ${key} = mlx.roleMap.models.${key} // {
                  id = "";
                };
              };
            }
          );
        }
      ];
    };

  positive = lib.mapAttrsToList (
    hostName: cfg:
    let
      msgs = failedMessages (primaryUser cfg);
    in
    lib.optionalString (msgs != "") "${hostName}: ${msgs}"
  ) configs;

  negative = lib.mapAttrsToList (
    hostName: cfg:
    let
      msg = failedMessages (primaryUser (broken cfg));
    in
    lib.optionalString (
      !(
        lib.hasInfix "must resolve to a non-empty physical model" msg
        || lib.hasInfix "differs from catalog" msg
      )
    ) "${hostName}: an empty model id did not fail the role-resolution assertion"
  ) configs;

  # A host's own `modelConcurrency` reaches the worker widths nix-ai renders.
  expectedWidths.jevans-mbp = {
    mimo-9b = 4;
    qwen38-27b = 2;
  };
  widthFailures = lib.concatMap (
    hostName:
    if !(configs ? ${hostName}) then
      [ "${hostName}: missing from the evaluated hosts, so its serving widths are unchecked" ]
    else
      let
        mlx = (primaryUser configs.${hostName}).programs.mlx;
      in
      lib.concatMap (
        key:
        let
          id = mlx.roleMap.models.${key}.id;
        in
        lib.optional (mlx.modelConcurrencyLimits.${id} != expectedWidths.${hostName}.${key})
          "${hostName}: ${key} serves width ${toString mlx.modelConcurrencyLimits.${id}}, expected ${
            toString expectedWidths.${hostName}.${key}
          }"
      ) (lib.attrNames expectedWidths.${hostName})
  ) (lib.attrNames expectedWidths);

  failures = lib.filter (m: m != "") (positive ++ negative ++ widthFailures);
in
assert
  failures == [ ] || throw "Role-map host check failed:\n${lib.concatStringsSep "\n" failures}";
pkgs.runCommand "check-role-map-hosts" { } ''
  echo "every declared role resolves on each host class; an empty model id fails the assertion"
  touch $out
''
