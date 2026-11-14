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
      # renovate: datasource=github-releases depName=vladkens/macmon
      version = "0.11.0";
      src = final.fetchFromGitHub {
        owner = "vladkens";
        repo = "macmon";
        tag = "v${finalAttrs.version}";
        hash = "sha256-TWrT5NG8XW/C7rgKMw06s+Ynsvly6bM1s+ffcV19tgo=";
      };
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) src;
        hash = "sha256-H6CaEsLR1yXtMTU8m30P1nUSG2QidK+IaOwzn6zgRxk=";
      };
      # The build sandbox cannot see launchd (pid 1), which this test samples.
      checkFlags = [ "--skip=procs::tests::samples_current_process" ];
    }
  );
}
