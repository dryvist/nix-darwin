# AI Stack — local model id supplier
#
# Required option since dryvist/nix-ai#878 collapsed the role registry to one
# configurable physical model id. nix-ai keeps the option generic ("never
# hardcoded in this repo"); the consumer supplies the value.
#
# The value is a non-secret public model name consumed at Nix EVAL time, so it
# lives committed in lib/hosts.nix (per-host) alongside every other eval-time
# identifier. Keeping it in-tree means evaluation stays pure — no `--impure`,
# no keychain/env/file sourcing. Change the model via a reviewed commit.
#
# roleModelOverrides (optional per-host registry field) pins selected roles to
# a different physical model — e.g. the Studio's `coding` role on a dedicated
# coder model — while every other role keeps following defaultLocalModelId.

{ hostConfig, ... }:

{
  services.aiStack = {
    inherit (hostConfig) defaultLocalModelId;
    roleOverrides = hostConfig.roleModelOverrides or { };
  };
}
