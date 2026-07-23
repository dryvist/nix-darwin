# AI Stack — catalog-populated local model roles
#
# Each MLX host assigns logical roles through nix-ai catalog selections. The
# physical model ids remain centralized in that catalog rather than repeated
# in deployed host configuration.

{
  services.aiStack.defaultLocalModelId = "";
}
