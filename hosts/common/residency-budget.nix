# Residency-budget guard: k_max x per-worker limit must fit the host ceiling.
#
# nix-ai states the invariant in modules/mlx/options-residency.nix —
#
#   maxResidentWorkers * memoryHardLimitGb <= host wired ceiling
#
# — but nothing enforced it anywhere. The two halves live in different repos and
# nix-ai cannot see the ceiling (that is a nix-darwin sysctl,
# system.appleSiliconTunables.wiredLimitMb, which nix-ai deliberately does not
# set). So the invariant was comment-enforced only, and an edit to EITHER side
# alone failed nothing:
#
#   - raising maxResidentWorkers without lowering memoryHardLimitGb silently
#     over-commits (2 workers at the 99 GiB default permits 198 GiB against a
#     100 GiB ceiling — the exact over-commit the k_max=1 default was introduced
#     to prevent, nix-ai#1515)
#   - lowering maxLocalLlmGb without revisiting the per-worker limit does the
#     same from the other direction
#
# nix-darwin evaluates both in one closure, so this is the only place the check
# can exist. Same bridge-and-assert shape as ./cluster-wired-limit.nix.
#
# WHAT THIS DOES NOT MEAN. mx.set_memory_limit is a sizing GUIDELINE, not a
# refusal: upstream MLX raises only when RAM and swap are exhausted, so a worker
# can transiently exceed its limit and the runtime will shed buffer cache rather
# than fail. This assertion therefore guards the BUDGET you chose, not a bound
# the runtime imposes. It also does not model the non-MLX wired baseline
# (~3.4 GiB measured on jevans-ms while decoding), so a configuration that
# passes at exactly the ceiling still has less headroom than the arithmetic
# suggests. Leave real cushion; do not tune this to equality.
{
  lib,
  config,
  osConfig,
  hostConfig,
  ...
}:
let
  # Attribute-existence gate (repo convention): non-inference hosts have no
  # `mlx` at all, so they must not be forced to satisfy a serving invariant.
  mlxHost = hostConfig ? mlx;
  tunables = osConfig.system.appleSiliconTunables or { };
  ceilingMb = tunables.wiredLimitMb or null;

  # Read the RESOLVED values, not hostConfig, so module defaults are covered:
  # a host that sets neither knob still gets 1 x 99 GiB checked against its
  # ceiling. That is the case a hostConfig-only read would silently skip.
  mlx = config.programs.mlx;
  kMax = mlx.maxResidentWorkers or 1;
  perWorkerGb = mlx.memoryHardLimitGb or 99;
  budgetMb = kMax * perWorkerGb * 1024;
in
{
  config = lib.mkIf (mlxHost && ceilingMb != null) {
    assertions = [
      {
        assertion = budgetMb <= ceilingMb;
        message = ''
          MLX residency budget over-commits this host's wired ceiling.

            maxResidentWorkers (${toString kMax})
              x memoryHardLimitGb (${toString perWorkerGb} GiB)
              = ${toString budgetMb} MiB
            wired ceiling (system.appleSiliconTunables.wiredLimitMb)
              = ${toString ceilingMb} MiB

          Raise maxResidentWorkers only alongside a lowered memoryHardLimitGb so
          the product still fits (nix-ai modules/mlx/options-residency.nix), or
          raise maxLocalLlmGb if the host genuinely has the memory. Note the
          product must leave room for the non-MLX wired baseline too, so fitting
          exactly is not the same as being safe.
        '';
      }
    ];
  };
}
