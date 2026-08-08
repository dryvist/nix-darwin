# Cluster rebuild gate — no system activation while a local rank is live.
#
# `darwin-rebuild switch` and a direct `/nix/var/nix/profiles/system/activate`
# both refuse on a host whose cluster rank is running. Detection is live
# launchd state on every call (see ./scripts/mlx-cluster-rank-live.sh); nothing
# is cached and no marker is written, because a marker outliving the rank would
# be a latch that blocks every future rebuild until a human clears it.
#
# The block window opens at RANK ACTIVATION — the moment the rank agent reports
# running, which is before the pair has finished rendezvousing and long before
# any health or generation-parity verdict exists. That is deliberate: the cost
# being avoided (a protection domain, returned only by a reboot) is spent by a
# failed re-formation, and a rank that is starting is exactly as expensive to
# interrupt as one that is serving. Confirming the two hosts agree on a
# generation is the cluster health gate's job and is not repeated here.
#
# KNOWN SEMANTICS — the profile moves before activation runs. `darwin-rebuild
# switch` does `nix-env -p /nix/var/nix/profiles/system --set` and only THEN
# runs the activate script this gate lives in, so a refusal leaves the system
# profile pointing at the new generation while the running system stays on the
# old one. Nothing about the live rank changes (which is the entire point), but
# the next boot will come up on the new generation. That is acceptable rather
# than accidental: a boot is itself a teardown, so the generation change lands
# on a host with no rank on it. Anyone chasing "the profile says one thing and
# the running system says another" after a refusal is looking at this, not at a
# failed rebuild.
#
# Enabled wherever the Thunderbolt cluster link is configured — a host with no
# cluster link can never have a rank, so it needs no gate.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  rankLivePkg = pkgs.writeShellApplication {
    name = "mlx-cluster-rank-live";
    text = builtins.readFile ./scripts/mlx-cluster-rank-live.sh;
  };

  gatePkg = pkgs.writeShellApplication {
    name = "cluster-rebuild-gate";
    runtimeEnv.MLX_CLUSTER_RANK_LIVE_BIN = lib.getExe rankLivePkg;
    text = builtins.readFile ./scripts/cluster-rebuild-gate.sh;
  };

  activationSnippet = lib.replaceStrings [ "@gate@" ] [ (lib.getExe gatePkg) ] (
    builtins.readFile ./scripts/cluster-rebuild-gate-activation.sh
  );
in
{
  # Declared unconditionally (options always are) so any consumer can reference
  # the detector without depending on the gate being enabled — there must stay
  # exactly one definition of "a rank is live", whoever is asking.
  options.system.clusterRebuildGate.rankLivePackage = lib.mkOption {
    type = lib.types.package;
    default = rankLivePkg;
    readOnly = true;
    description = "The built mlx-cluster-rank-live derivation, for other modules that must ask the same question the gate asks.";
  };

  config = lib.mkIf config.system.clusterLinkPrep.enable {
    # mkOrder 50 runs ahead of mkBefore (500). Several modules here already
    # use mkBefore for preActivation and their relative order is merge order,
    # not a guarantee; the refusal must land before any of them has touched
    # the machine. See ./scripts/cluster-rebuild-gate-activation.sh for why
    # the snippet exits explicitly rather than relying on `set -e`.
    system.activationScripts.preActivation.text = lib.mkOrder 50 activationSnippet;

    # On PATH so the same detection an operator asks about ("why did my rebuild
    # refuse?") is the detection the gate used, rather than a second opinion.
    environment.systemPackages = [ rankLivePkg ];
  };
}
