# Projects the LLM role map (programs.mlx.roleMap) onto one host class: the
# catalog selection, preload roles, per-model concurrency, resident-worker
# count and the role -> physical id registry. A role belongs to a class when
# its model (with the class's own `roles` overrides applied) is one the class
# keeps. A class absent from the map projects nothing.
#
# `concurrency` is one host's own per-model serving width, keyed by role-map
# model key. It wins over the shared catalog width for that host alone; naming
# a model the class does not keep is an error, not a silent no-op.
{
  lib,
  roleMap,
  concurrency ? { },
}:
class:
let
  host = roleMap.hosts.${class} or null;
  kept = if host == null then [ ] else host.resident ++ host.swap;
  roles = roleMap.roles // (host.roles or { });
  classRoles = lib.filterAttrs (_: r: r.model != null && lib.elem r.model kept) roles;
  rolesOf = key: lib.attrNames (lib.filterAttrs (_: r: r.model == key) classRoles);
  # A resident model with no role has nothing to warm by name.
  preloadable = lib.filter (key: rolesOf key != [ ]) (host.resident or [ ]);
  unkept = lib.filter (key: !(lib.elem key kept)) (lib.attrNames concurrency);
  widthOf = key: concurrency.${key} or roleMap.models.${key}.concurrency;
in
assert lib.assertMsg (unkept == [ ])
  "host modelConcurrency names models the `${class}` class does not keep: ${lib.concatStringsSep ", " unkept}";
{
  catalog = lib.genAttrs kept (key: {
    class = if lib.elem key host.resident then "resident" else "swap";
    roles = rolesOf key;
  });
  maxResidentWorkers = lib.length (host.resident or [ ]);
  preload = map (key: lib.head (rolesOf key)) preloadable;
  modelConcurrencyLimits = lib.listToAttrs (
    map (key: lib.nameValuePair roleMap.models.${key}.id (widthOf key)) kept
  );
  aiStackModels = lib.mapAttrs (_: r: roleMap.models.${r.model}.id) classRoles;
}
