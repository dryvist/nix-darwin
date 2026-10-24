# TEMPORARY: macmon with the `serve` Prometheus exporter
#
# `macmon serve` (HTTP /metrics) first shipped in v0.9.0; the pinned nixpkgs
# still carries an older release without it. The homelab scrapes it for Mac
# GPU busy %.
#
# REMOVE THIS OVERLAY when the pinned nixpkgs carries macmon >= 0.9.0.

final: prev:
prev.lib.optionalAttrs prev.stdenv.isDarwin {
  macmon = prev.macmon.overrideAttrs (
    finalAttrs: _: {
      version = "0.10.0";
      src = final.fetchFromGitHub {
        owner = "vladkens";
        repo = "macmon";
        tag = "v${finalAttrs.version}";
        hash = "sha256-/nZTmnM2OT/iDB+vmVd5SptCOCUUF4yn2/Yu45At/0E=";
      };
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) src;
        hash = "sha256-hk3PCNLfUrOT+wT8ZLWd2KZWTYK7Kv8+2a1jBIO7Ti8=";
      };
      # The build sandbox cannot see launchd (pid 1), which this test samples.
      checkFlags = [ "--skip=procs::tests::samples_current_process" ];
    }
  );
}
