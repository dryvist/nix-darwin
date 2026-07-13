# Ensure a dedicated "git" APFS volume (100 GiB quota) exists on the internal
# APFS container. Create-if-absent — no data migration, and re-runs are no-ops.
#
# The container is resolved at runtime from the booted root volume, so no disk
# identifier is hardcoded: the volume always lands on the internal store the OS
# boots from, regardless of its transient disk id.
#
# macOS system binaries (diskutil, plutil, grep) are called by absolute path —
# writeShellApplication restricts PATH to runtimeInputs, and these are macOS-only
# tools that are not in nixpkgs.

volume_name="git"
quota="100g"

# Resolve the internal APFS container from the booted root volume.
container="$(/usr/sbin/diskutil info -plist / | /usr/bin/plutil -extract APFSContainerReference raw -)"
if [ -z "$container" ]; then
  echo "[git-apfs-volume] could not resolve internal APFS container from /" >&2
  exit 1
fi

# Guard: a volume named "git" already exists on the target container -> nothing
# to do. APFS volume names are case-insensitive, so match case-insensitively on
# the complete "Name:" field without depending on a parenthetical suffix.
if /usr/sbin/diskutil apfs list "$container" | /usr/bin/grep -qiE "Name:[[:space:]]+${volume_name}([[:space:]]+\(|$)"; then
  echo "[git-apfs-volume] volume '${volume_name}' already exists on container ${container}; nothing to do"
  exit 0
fi

echo "[git-apfs-volume] creating volume '${volume_name}' (quota ${quota}) on container ${container}"
/usr/sbin/diskutil apfs addVolume "$container" APFS "$volume_name" -quota "$quota"
