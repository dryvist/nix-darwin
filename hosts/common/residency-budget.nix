# Residency budget: DERIVE the per-worker limit, then assert it fits.
#
# `maxLocalLlmGb` is documented as "the single knob; everything downstream
# derives" — wiredLimitMb and osReserveGb already do. memoryHardLimitGb never
# joined that chain: it was a hand-computed literal per host, so every future
# change to the ceiling or to k_max required someone to redo the arithmetic and
# get it right. This module closes that gap. The only numbers a host states are
# the ceiling (maxLocalLlmGb) and how many workers may hold weights
# (maxResidentWorkers); the per-worker budget follows:
#
#   memoryHardLimitGb = (maxLocalLlmGb - baselineReserveGb) / maxResidentWorkers
#
# nix-ai states the invariant in modules/mlx/options-residency.nix —
#
#   maxResidentWorkers * memoryHardLimitGb <= host wired ceiling
#
# — but cannot enforce or derive it: the ceiling is a nix-darwin sysctl
# (system.appleSiliconTunables.wiredLimitMb) that nix-ai deliberately does not
# set. nix-darwin evaluates both halves in one closure, so this is the only
# place either can happen. Same bridge shape as ./cluster-wired-limit.nix.
#
# The assertion is kept as a backstop for a host that overrides the derived
# value explicitly. Derivation makes the common path correct by construction;
# the assertion catches the deliberate exception.
#
# WHAT THIS DOES NOT MEAN. mx.set_memory_limit is a sizing GUIDELINE, not a
# refusal: upstream MLX raises only when RAM and swap are exhausted, so a worker
# can transiently exceed its limit and the runtime sheds buffer cache rather
# than failing. This guards the BUDGET you chose, not a bound the runtime
# imposes.
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

  # Read the RESOLVED value, not hostConfig, so module defaults are covered too.
  kMax = config.programs.mlx.maxResidentWorkers or 1;

  # Wired GiB the budget must NOT claim. Measured ~3.4 GiB host-wide on
  # jevans-ms while one worker decodes (non-MLX baseline: WindowServer, the
  # proxy, system daemons). Ignoring it is what made an earlier "4 GiB cushion"
  # claim wrong: 2 x 48 + 3.4 = 99.4 against 100, so the true cushion was
  # ~0.6 GiB. 4 rounds that measurement up to a whole GiB.
  baselineReserveGb = 4;

  ceilingGb = ceilingMb / 1024;
  derivedPerWorkerGb = (ceilingGb - baselineReserveGb) / kMax;

  perWorkerGb = config.programs.mlx.memoryHardLimitGb;
  budgetMb = kMax * perWorkerGb * 1024;
in
{
  config = lib.mkIf (mlxHost && ceilingMb != null) {
    # mkDefault so a host can still override deliberately; the assertion then
    # holds that override to the same invariant.
    programs.mlx.memoryHardLimitGb = lib.mkDefault derivedPerWorkerGb;

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

          The per-worker limit normally DERIVES from the ceiling and k_max, so
          reaching this means a host overrode memoryHardLimitGb by hand. Drop
          the override and let it derive, raise maxLocalLlmGb if the host
          genuinely has the memory, or lower maxResidentWorkers.
        '';
      }
    ];
  };
}
