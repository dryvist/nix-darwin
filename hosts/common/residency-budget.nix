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

  # --- the vllm-mlx half of the same budget ------------------------------
  #
  # memoryHardLimitGb is applied by the mlx-lm launcher via mx.set_memory_limit
  # and is INERT under vllm-mlx. There the per-worker cap is instead
  # gpuMemoryUtilization, a FRACTION — so the same budget has to be expressed
  # twice, in different units, or the second one derives from nothing. It
  # derived from nothing: a flat 0.8 that ignores both the ceiling and k_max,
  # which on a 2-resident host grants 2 x 0.8 x 100 = 160 GiB against a 100 GiB
  # ceiling.
  #
  # The fraction has TWO independent constraints, on two different bases. Read
  # from the installed vllm-mlx source, because its own documentation states
  # one base for both:
  #
  #   cap  = max_recommended_working_set_size * util
  #   trip = memory_size * (util + 0.05)      <- physical RAM, not the ceiling
  #
  # 1. CAP: the per-worker allocation limit must equal the budget already
  #    derived above, so both backends bound a worker identically.
  #      util <= perWorkerGb / maxRecommendedGb
  #
  # 2. TRIP: the emergency cache-clear must be able to fire BELOW the wired
  #    ceiling. Above it the valve is unreachable and the process swaps or dies
  #    first — which is the state a flat 0.8 leaves this host in today
  #    (0.85 x 128 = 108.8 GiB, above a 100 GiB ceiling).
  #      util <  ceilingGb / physicalRamGb - 0.05
  #
  # Take the lower. Neither constraint alone is sufficient and they do not
  # reduce to each other.
  #
  # maxRecommendedGb is ceilingGb: Metal reports max_recommended_working_set_size
  # equal to iogpu.wired_limit_mb whenever that sysctl is set, and this module
  # only runs where wiredLimitMb is non-null — which is what sets it. The
  # assertion below refuses the case where that identity would not hold.
  #
  # Float math is deliberate. Nix integer division truncates, and every one of
  # these ratios is between 0 and 1, so an int expression here evaluates to 0
  # and then fails the option's own 0.05 lower bound.
  physicalRamGb = tunables.physicalRamGb or null;
  utilFromCap = (perWorkerGb * 1.0) / ceilingGb;
  utilFromTrip = ((ceilingGb * 1.0) / physicalRamGb) - 0.05;
  derivedUtil = lib.min utilFromCap utilFromTrip;

  vllmSelected = config.programs.mlx.modelServerBackend or "mlx-lm" == "vllm-mlx";
  currentUtil = config.programs.mlx.gpuMemoryUtilization;
  tripReachable = currentUtil == null || ((currentUtil + 0.05) * physicalRamGb) < (ceilingGb * 1.0);
in
{
  config = lib.mkIf (mlxHost && ceilingMb != null) {
    # mkDefault so a host can still override deliberately; the assertion then
    # holds that override to the same invariant.
    programs.mlx.memoryHardLimitGb = lib.mkDefault derivedPerWorkerGb;

    # Derived unconditionally, not only when vllm-mlx is selected. The fraction
    # means the same thing whichever backend reads it, and making the NUMBER
    # depend on the backend is the same false-capability shape that let a
    # batching flag read as enabled on a backend that ignores it. On an mlx-lm
    # host nothing consumes it, so this changes no behaviour there.
    programs.mlx.gpuMemoryUtilization = lib.mkIf (physicalRamGb != null) (lib.mkDefault derivedUtil);

    assertions = [
      {
        # Gated on vllm-mlx because the fraction is inert under mlx-lm: firing
        # there would block every host today over a knob none of them read.
        # Under vllm-mlx it is the ONLY per-worker enforcement, so an
        # unreachable trip means the emergency valve silently does not exist.
        assertion = !vllmSelected || physicalRamGb == null || tripReachable;
        message = ''
          programs.mlx.gpuMemoryUtilization leaves the emergency cache-clear
          unreachable on this host, and vllm-mlx is the selected backend.

            gpuMemoryUtilization  = ${toString currentUtil}
            trip                  = (util + 0.05) x physicalRamGb
                                  = ${toString ((currentUtil + 0.05) * physicalRamGb)} GiB
            wired ceiling         = ${toString ceilingGb} GiB

          The trip is computed on PHYSICAL RAM while the allocation cap is
          computed on the wired ceiling, so a fraction that looks safe against
          the cap can put the trip above the ceiling — where it can never fire
          and the worker swaps instead. Drop the override and let this module
          derive the fraction, or lower it below
          ${toString (((ceilingGb * 1.0) / physicalRamGb) - 0.05)}.
        '';
      }
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
