# TEMPORARY WORKAROUND: Python packages with darwin-incompatible test phases
#
# Two packages in the open-webui dependency chain (pulled in by nix-ai) cannot
# evaluate or build on aarch64-darwin because their test infrastructure is
# Linux-specific or requires GPU/distributed-training hardware that the Nix
# sandbox cannot provide. Both blocks darwin-rebuild and `nix flake check`.
#
# WHY overridePythonAttrs (not overrideAttrs):
# buildPythonPackage merges nativeCheckInputs into nativeBuildInputs BEFORE
# overrideAttrs can intercept, so `overrideAttrs { doCheck = false; }` leaves
# the broken/unbuildable test deps in nativeBuildInputs and the build still
# fails. overridePythonAttrs re-runs buildPythonPackage with the new arguments,
# so clearing nativeCheckInputs actually removes the deps from the graph.
#
# Affected packages:
#
#   pgvector — nativeCheckInputs includes postgresqlTestHook, which is
#   marked meta.broken = true on aarch64-darwin (Linux-specific PostgreSQL
#   build machinery). Evaluation fails before the build even starts.
#
#   accelerate — nativeCheckInputs run a Hugging Face test suite that
#   assumes CUDA/MPS/distributed-training. Tests crash with SIGTRAP
#   (Bus Error) inside the Nix sandbox.
#
# Both are runtime deps of open-webui only; their tests are irrelevant for
# our use case.
#
# REMOVE THIS OVERLAY when nixpkgs ships a fix — either postgresqlTestHook
# becomes buildable on darwin / gated by meta.platforms, or pgvector and
# accelerate gate their nativeCheckInputs by stdenv.isLinux. Re-test by
# removing the overlay and running `sudo darwin-rebuild switch --flake .`.
#
# Longer-term: open-webui is a server app; deploying via Docker (OrbStack)
# eliminates this entire class of problem. Tracked separately.

_final: prev:
prev.lib.optionalAttrs prev.stdenv.isDarwin {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pprev: {
      pgvector = pprev.pgvector.overridePythonAttrs (_: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });

      accelerate = pprev.accelerate.overridePythonAttrs (_: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });

      # a2a-sdk — e2e push-notification tests fork a FastAPI test server with
      # multiprocessing; the darwin spawn start method cannot pickle the
      # locally-defined openapi closure, so setup errors on every run.
      a2a-sdk = pprev.a2a-sdk.overridePythonAttrs (_: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });
    })
  ];
}
