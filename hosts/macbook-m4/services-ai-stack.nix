# AI Stack — local model id supplier
#
# Required option since dryvist/nix-ai#878 collapsed the role registry to a
# single configurable physical model id. Reads from the `AI_MODEL_LOCAL_LLM`
# env var, which the home.nix shell-initContent block exports from the
# no-password automation keychain. `darwin-rebuild switch --impure` is
# required so `builtins.getEnv` resolves.
#
# The keychain value must be the full physical model id (no prefix
# synthesis on this side). Build fails fast with a message naming the
# keychain item if the env is unset.

{ ... }:

{
  services.aiStack.defaultLocalModelId =
    let
      raw = builtins.getEnv "AI_MODEL_LOCAL_LLM";
    in
    if raw == "" then
      throw "AI_MODEL_LOCAL_LLM env var is unset. Verify the automation-keychain item `AI_MODEL_LOCAL_LLM` exists (full physical model id) and that `darwin-rebuild switch --impure` is invoked from a shell where the home.nix initContent has already exported it."
    else
      raw;
}
