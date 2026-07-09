# Per-host registry — aggregator only; each host lives in lib/hosts/<name>.nix
# and the shared LLM serving catalog in lib/hosts/llm-serving.nix (#1610).
#
# Pure static data only — NO `config`/`osConfig`/module references (that would
# create an eval-order dependency). Consumed by flake.nix `mkHost`, which
# normalizes `class` (default "workstation") and derives `isServer`, then
# threads each host's attrset to darwin modules via `specialArgs.hostConfig`
# and to home-manager modules via `extraSpecialArgs.hostConfig`.
#
# Keyed by descriptive machine label (also the folder name under hosts/). The
# darwin configuration is exposed under `hostName` (see flake.nix) so
# `darwin-rebuild switch --flake .` host auto-detection resolves it.
#
# Fields are added here as consumers are wired up (PR-by-PR): a field lives in
# the registry only once a module or host file actually reads it, to avoid data
# that duplicates a host file without being consumed.
{
  macbook-m4 = import ./hosts/macbook-m4.nix;
  mac-studio = import ./hosts/mac-studio.nix;
}
