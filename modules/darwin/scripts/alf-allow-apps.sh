# Point the application firewall at the current Nix store path of each allowed app.
#
# The firewall keys an ad-hoc-signed binary by its signing identifier, which for
# a linker-signed Nix build is the executable name. After a version bump the old
# entry keeps that identifier while its store path is usually garbage-collected,
# and `--add` of the new path does not replace it. So for each allowed Nix store
# path, remove every other Nix store entry with the same executable name, then add
# and unblock all allowed paths. Paths outside the store (uv CPython) are only
# added and unblocked. Every call is idempotent, so running this on each
# activation is safe.
SFW=${ALF_SOCKETFILTERFW:-/usr/libexec/ApplicationFirewall/socketfilterfw}
declare -A allowed=() names=()
for app in "$@"; do
  allowed[$app]=1
  if [[ $app == /nix/store/* ]]; then names[${app##*/}]=1; fi
done
while IFS= read -r line; do
  [[ $line =~ ^[0-9]+[[:space:]]*:[[:space:]]*(/nix/store/[^[:space:]]+) ]] || continue
  listed=${BASH_REMATCH[1]}
  [[ -n ${names[${listed##*/}]:-} && -z ${allowed[$listed]:-} ]] || continue
  # stdout is success noise; stderr stays visible in the activation log.
  if "$SFW" --remove "$listed" >/dev/null; then
    echo "alf-allow-apps: removed stale $listed"
  else
    echo "alf-allow-apps: could not remove stale $listed"
  fi
done < <("$SFW" --listapps || true)
for app in "$@"; do
  "$SFW" --add "$app" >/dev/null || true
  "$SFW" --unblockapp "$app" >/dev/null || true
  echo "alf-allow-apps: allowed $app"
done
