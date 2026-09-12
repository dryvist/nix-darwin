# Bring up the per-user Apple container apiserver, then prove it came up.
#
# `container system start` exits 0 whether or not it actually registered the
# apiserver, so the launchd unit reports success for a runtime that never came
# up, and every `container run` downstream fails against a dependency nothing
# flagged. `container system status` exits 1 while the apiserver is down, so
# running it afterwards makes this unit's exit code mean what it says.
#
# $1 is the container CLI path (a config option, hence an argument).

container_bin="$1"

"${container_bin}" system start --enable-kernel-install
"${container_bin}" system status
