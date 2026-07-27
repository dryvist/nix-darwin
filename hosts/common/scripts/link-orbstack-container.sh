# Point the OrbStack Group Container at its dedicated APFS volume, so all
# OrbStack data (Docker images, containers, volumes, Linux VMs, logs) lives
# there rather than on the boot disk.
#
# This is NOT a home.file entry, and must not become one again. Two reasons,
# both of which cost a full deployment on 2026-07-25:
#
#  1. home.file's link step runs `ln -Tsf` unconditionally on every managed
#     path, every generation. A write into ~/Library/Group Containers on that
#     machine does not fail — it HANGS indefinitely, for every process tried
#     (`touch` there returns 124 from a plain shell, from Terminal.app, and
#     under sudo; OrbStack was not running, so the "directory is locked while
#     OrbStack runs" explanation this code used to carry was wrong — it is a
#     macOS privacy gate on the container directory). home-manager's link
#     helper ends in `ln ... || exit 1`, so the whole batch died and every
#     remaining file in it was skipped, silently, while darwin-rebuild still
#     exited 0. A "successful" rebuild deployed none of its changes.
#
#  2. home.file routes the link through the per-generation files directory, so
#     the link target changed on EVERY generation and could never already be
#     correct. Pointing straight at the volume makes the desired state stable,
#     so the steady state is a no-op and the dangerous write is never attempted.
#
# Bounded and non-fatal by construction: activation must never again be able to
# wedge on this one symlink.
target="/Volumes/$ORBSTACK_CONTAINER_VOLUME"
link="$HOME/Library/Group Containers/HUAQ24HBR6.dev.orbstack"

if [ "$(readlink "$link" 2> /dev/null)" = "$target" ]; then
  echo "orbstack: container symlink already points at $target; nothing to do"
  exit 0
fi

if [ ! -d "$target" ]; then
  echo "orbstack: $target is not mounted; leaving the container symlink alone" >&2
  exit 0
fi

# timeout, because the failure mode here is a hang rather than an error.
if timeout 10 ln -Tsf "$target" "$link"; then
  echo "orbstack: pointed the container symlink at $target"
else
  echo "orbstack: could not update the container symlink (privacy gate on ~/Library/Group Containers, or OrbStack holding it). Continuing — this must never block activation." >&2
fi
exit 0
