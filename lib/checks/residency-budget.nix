# The residency budget must fit under the wired ceiling, and its assertion must
# catch an override that does not. Evaluates the real module with stub options,
# so it runs on the Linux CI runner without a darwin evaluation.
{ pkgs, src }:
let
  inherit (pkgs) lib;
  eval =
    {
      wiredLimitMb,
      maxResidentWorkers,
      override ? null,
      mlx ? true,
    }:
    (lib.evalModules {
      specialArgs = {
        inherit lib;
        osConfig.system.appleSiliconTunables.wiredLimitMb = wiredLimitMb;
        hostConfig = lib.optionalAttrs mlx { mlx = { }; };
      };
      modules = [
        (src + "/hosts/common/residency-budget.nix")
        {
          options = {
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.unspecified;
              default = [ ];
            };
            programs.mlx.memoryHardLimitGb = lib.mkOption { type = lib.types.number; };
            programs.mlx.maxResidentWorkers = lib.mkOption {
              type = lib.types.int;
              default = 1;
            };
          };
          config = {
            programs.mlx.maxResidentWorkers = maxResidentWorkers;
          }
          // lib.optionalAttrs (override != null) { programs.mlx.memoryHardLimitGb = override; };
        }
      ];
    }).config;
  holds = cfg: lib.all (a: a.assertion) cfg.assertions;
  twoWorkers = eval {
    wiredLimitMb = 100 * 1024;
    maxResidentWorkers = 2;
  };
  overcommit = eval {
    wiredLimitMb = 100 * 1024;
    maxResidentWorkers = 2;
    override = 99;
  };
  oneWorkerOverride = eval {
    wiredLimitMb = 64 * 1024;
    maxResidentWorkers = 1;
    override = 30;
  };
  noMlx = eval {
    wiredLimitMb = 100 * 1024;
    maxResidentWorkers = 2;
    mlx = false;
  };
in
assert twoWorkers.programs.mlx.memoryHardLimitGb == 48;
assert lib.length twoWorkers.assertions == 1;
assert holds twoWorkers;
assert !(holds overcommit);
assert holds oneWorkerOverride;
assert noMlx.assertions == [ ];
pkgs.runCommand "check-residency-budget" { } ''
  touch "$out"
''
