# Cribl Stream (local egress aggregator) — DISABLED (idle)
#
# Split out of cribl.nix (repo file-size gate). See that file for the Edge
# config; this module only carries the idle local-Stream + container runtime.

_:

let
  userConfig = import ../../lib/user-config.nix;
in
{
  programs = {
    # --- Cribl Stream (local egress aggregator) — DISABLED (idle) ---
    # The local-Stream cutover is reverted: cribl-edge ships directly to the
    # Proxmox HAProxy (:10300), so a local Stream listening on :10301 receives
    # nothing and sits idle. Apple `container` runs it as a lightweight VM whose
    # `--memory` is the VM's RAM allocation (not a soft cap), so running it idle
    # would tie up ~1 GB + a CPU for zero benefit — unacceptable on inference
    # hosts where RAM is reserved for MLX. Kept configured (not deleted) so
    # re-enabling is a one-line flip once the containerized Stream's CPU/DNS issue
    # is fixed and the cutover is ready — right-size cpus/memory against real load
    # THEN (the module defaults 1 cpu / 1g / 1 worker are conservative starting
    # points, not a measured requirement). To re-enable: enable = lib.mkIf
    # (hostConfig ? mlx) true. No explicit container DNS: Apple `container`
    # forwards through the vmnet gateway to the host resolver. See docs/CRIBL-GITOPS.md.
    cribl-stream = {
      enable = false;
      user = userConfig.user.name;
      inputPort = 10301;
      apiPort = 9000;
      configFiles = {
        "inputs.yml" = ''
          inputs:
            in_edge_s2s:
              type: cribl_tcp
              disabled: false
              host: 0.0.0.0
              port: 10301
              sendToRoutes: false
              connections:
                - pipeline: passthrough
                  output: proxmox_stream
        '';
        "outputs.yml" = ''
          outputs:
            proxmox_stream:
              type: cribl_tcp
              # Homelab HAProxy (FQDN), load-balanced across the Proxmox Cribl Stream workers.
              host: ${userConfig.logging.syslog.server}
              port: 10300
              pqEnabled: true
              # Bounded on-disk queue: cap size and drop when full.
              pqMaxFileSize: 256 MB
              pqMaxSize: 1 GB
              pqOnBackpressure: drop
        '';
        # Passthrough for now; index/sourcetype enrichment moves here from Edge
        # once Edge is repointed (Edge captures, Stream enriches + egresses).
        "pipelines/passthrough/conf.yml" = ''
          output: default
          functions: []
        '';
      };
    };
  };
}
