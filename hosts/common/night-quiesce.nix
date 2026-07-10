# Worker-side night-cluster hooks (split out for the per-file byte cap).
#
# Wires the night-quiesce/restore scripts into nix-ai's
# programs.mlx.nightCluster link watcher on the worker Mac: link-up quits
# GUI apps and boots out non-allowlisted user agents before the rank starts;
# link-down bootstraps the recorded set back. Coordinator hosts get their
# quiesce natively from the watcher (llama-swap unload + warmup re-warm),
# so this module is worker-only.
{
  lib,
  pkgs,
  hostConfig,
  ...
}:
let
  # Attribute-existence gate (repo convention), not a bare `or` fallback:
  # non-inference hosts have no `mlx` at all.
  nightRole =
    if hostConfig ? mlx && hostConfig.mlx ? nightCluster then
      hostConfig.mlx.nightCluster.role or null
    else
      null;

  quiescePkg = pkgs.writeShellApplication {
    name = "night-quiesce";
    text = builtins.readFile ./scripts/night-quiesce.sh;
  };

  restorePkg = pkgs.writeShellApplication {
    name = "night-restore";
    text = builtins.readFile ./scripts/night-restore.sh;
  };
in
{
  config = lib.mkIf (nightRole == "worker") {
    programs.mlx.nightCluster = {
      quiesceCommand = lib.getExe quiescePkg;
      restoreCommand = lib.getExe restorePkg;
    };

    # On PATH for the pre-plug verification: run the pair manually WITHOUT a
    # cable and assert the post-quiesce agent table matches the allowlist.
    home.packages = [
      quiescePkg
      restorePkg
    ];
  };
}
