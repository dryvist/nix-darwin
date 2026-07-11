# AI Stack — shared local model id supplier
#
# Required option since dryvist/nix-ai#878 collapsed the role registry to one
# configurable physical model id. nix-ai keeps the option generic ("never
# hardcoded in this repo"); this consumer pins the value.
#
# The default local model is SHARED across every host and pinned here — not per
# host. There is deliberately no per-host `defaultLocalModelId`: every host
# resolves the `default` role to the one id below, so hosts cannot drift to
# different defaults. It is a non-secret public model name consumed at Nix EVAL
# time, so keeping it in-tree keeps evaluation pure (no `--impure`, no
# keychain/env/file sourcing). Change the model via a reviewed commit.
#
# roleModelOverrides (optional per-host registry field) still pins selected
# NON-default roles to a different physical model — e.g. the Studio's
# tool-calling role on OptiQ — so other models stay available on demand. Only
# the default role is locked to the shared id below.

{ hostConfig, ... }:

{
  services.aiStack = {
    defaultLocalModelId = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
    roleOverrides = hostConfig.roleModelOverrides or { };
  };
}
