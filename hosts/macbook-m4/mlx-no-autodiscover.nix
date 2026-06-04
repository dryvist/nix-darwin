# Disable nix-ai's auto-discovery of locally-cached HuggingFace models.
#
# nix-ai/modules/mlx/launchd.nix registers a `discoverMlxModels` home-manager
# activation hook that scans the HuggingFace cache and merges every locally
# present model into the runtime llama-swap config. That defeats the
# "one resident model" posture this host enforces — the moment any model is
# in the HF cache, it ends up in the registry and any caller can request it,
# producing the swap-thrash this whole PR set is meant to eliminate.
#
# Override the activation with an empty string. The seedLlamaSwapConfig
# hook stays, so the runtime config still gets bootstrapped from the
# nix-generated base on a fresh rebuild.

{ lib, ... }:

{
  home.activation.discoverMlxModels = lib.mkForce "";
}
