# AI Stack — local model id supplier
#
# Required option since dryvist/nix-ai#878 collapsed the role registry to
# one configurable physical model id. Two-source lookup, file first then
# env fallback.
#
# Primary: file at the path below. Populated from the no-password
# automation keychain item by the home.nix activation hook. Reading from
# a file sidesteps macOS sudo env-reset policy on this host, which strips
# arbitrary env vars. Root reads user files, so privileged rebuilds work
# without env passthrough.
#
# Fallback: AI_MODEL_LOCAL_LLM env var. Used by CI runners (workflow
# injects the value from the dryvist org variable) and on first rebuild
# before the activation hook has run.
#
# The value must be the full physical model id; this consumer reads it
# verbatim. Build fails fast with a clear message when neither source
# is populated.

{ config, ... }:

let
  modelIdPath = "${config.home.homeDirectory}/.config/ai-stack/local-model-id";
  fromFile =
    if builtins.pathExists modelIdPath then
      builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile modelIdPath)
    else
      "";
  fromEnv = builtins.getEnv "AI_MODEL_LOCAL_LLM";
  raw = if fromFile != "" then fromFile else fromEnv;
in
{
  services.aiStack.defaultLocalModelId =
    if raw == "" then
      throw "services.aiStack.defaultLocalModelId not set. Neither ${modelIdPath} nor the AI_MODEL_LOCAL_LLM env var is populated. The file is refreshed from the AI_MODEL_LOCAL_LLM automation-keychain item by the home.nix activation hook; in CI the env var is injected from the dryvist org variable."
    else
      raw;
}
