# shellcheck shell=bash
# The preActivation snippet that runs the cluster rebuild gate. Substituted
# into the activation script by ../cluster-rebuild-gate.nix, which substitutes
# the built gate's store path into the last line.
#
# THE `|| exit 1` IS THE WHOLE POINT, and it is not redundant with `set -e`.
# Activation in this repo runs `set +e` deliberately, so that a non-zero exit
# from something like `launchctl asuser` cannot abort a deploy half-applied.
# A gate that merely exited non-zero would therefore be IGNORED: it would print
# a refusal, the rebuild would carry on regardless, and the log would read
# exactly like a working guard. Exiting explicitly does not depend on `set -e`
# being in force at this point.
#
# Stopping here is safe. This snippet is ordered ahead of every other
# activation step, so nothing has been applied yet — a refusal leaves the
# running system untouched rather than half-built.
@gate@ || exit 1
