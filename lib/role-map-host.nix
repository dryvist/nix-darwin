# Projects the LLM role map (programs.mlx.roleMap) onto one host class: the
# catalog selection, preload roles, per-model concurrency, resident-worker
# count and the role -> physical id registry. A role belongs to a class when
# its model (with the class's own `roles` overrides applied) is one the class
# keeps. A class absent from the map projects nothing.
{ lib, roleMap }:
class:
let
  host = roleMap.hosts.${class} or null;
  kept = if host == null then [ ] else host.resident ++ host.swap;
  roles = roleMap.roles // (host.roles or { });
  classRoles = lib.filterAttrs (_: r: r.model != null && lib.elem r.model kept) roles;
  rolesOf = key: lib.attrNames (lib.filterAttrs (_: r: r.model == key) classRoles);
  # A resident model with no role has nothing to warm by name.
  preloadable = lib.filter (key: rolesOf key != [ ]) (host.resident or [ ]);
in
{
  catalog = lib.genAttrs kept (key: {
    class = if lib.elem key host.resident then "resident" else "swap";
    roles = rolesOf key;
  });
  maxResidentWorkers = lib.length (host.resident or [ ]);
  preload = map (key: lib.head (rolesOf key)) preloadable;
  modelConcurrencyLimits = lib.listToAttrs (
    map (key: lib.nameValuePair roleMap.models.${key}.id roleMap.models.${key}.concurrency) kept
  );
  aiStackModels = lib.mapAttrs (_: r: roleMap.models.${r.model}.id) classRoles;
}
