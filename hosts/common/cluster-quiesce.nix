# Worker-side cluster-mode hooks (split out for the per-file byte cap).
#
# Wires the cluster-quiesce/restore scripts into nix-ai's
# programs.mlx.clusterMode link watcher on the worker Mac: link-up quits
# GUI apps and boots out non-allowlisted user agents before the rank starts;
# link-down bootstraps the recorded set back. Coordinator hosts get their
# quiesce natively from the watcher (llama-swap unload + warmup re-warm),
# so this module is worker-only.
{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}:
let
  # Attribute-existence gate (repo convention), not a bare `or` fallback:
  # non-inference hosts have no `mlx` at all.
  clusterRole =
    if hostConfig ? mlx && hostConfig.mlx ? clusterMode then
      hostConfig.mlx.clusterMode.role or null
    else
      null;

  quiescePkg = pkgs.writeShellApplication {
    name = "cluster-quiesce";
    # coreutils for `timeout`, which bounds the GUI quit sweep. macOS ships no
    # timeout(1), so without this the wrapper cannot fail closed on a hung
    # osascript — the exact 2026-08-07 wedge.
    runtimeInputs = [ pkgs.coreutils ];
    # Feed the terminal keep list to the script (newline-separated) so a
    # session in a non-default terminal can be protected from the GUI quit
    # without editing the public script.
    runtimeEnv.CLUSTER_QUIESCE_TERMINALS = lib.concatStringsSep "\n" config.programs.clusterQuiesce.terminalAllowlist;
    text = builtins.readFile ./scripts/cluster-quiesce.sh;
  };

  restorePkg = pkgs.writeShellApplication {
    name = "cluster-restore";
    text = builtins.readFile ./scripts/cluster-restore.sh;
  };
in
{
  options.programs.clusterQuiesce.terminalAllowlist = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "Finder"
      "Ghostty"
      "Terminal"
      "iTerm2"
      "WezTerm"
      "Alacritty"
      "kitty"
    ];
    description = ''
      GUI apps cluster-quiesce leaves running so a live cable-test session
      cannot quit its own terminal. Add the terminal you run the test from if
      it is not one of the macOS defaults listed here.
    '';
  };

  config = lib.mkIf (clusterRole == "worker") {
    programs.mlx.clusterMode = {
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
