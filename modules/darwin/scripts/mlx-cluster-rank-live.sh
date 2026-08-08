# shellcheck shell=bash
# Is a local MLX cluster rank live RIGHT NOW?
#
# The single definition of "this host is clustered" for every consumer on the
# machine. It exists as one command rather than one copied conditional because
# the consumers disagree in consequence — one refuses a system activation, one
# opens and closes a maintenance window — and two detections that can drift
# apart would eventually block a rebuild over a window that was never opened,
# or leave a window open over a host that is free.
#
# LIVE STATE ONLY. Deliberately no marker file, no cached verdict, no "we were
# clustered at 04:12" stamp. A marker that outlives the rank is a latch, and a
# latch whose only clear is a human is a defect the moment automation can trip
# it: the machine would refuse every rebuild forever after one unclean
# teardown. launchd is the authority on whether the rank agent is running, so
# launchd is asked, every time, and nothing is remembered between calls.
#
# The rank runs in the console user's GUI launchd domain (it needs the macOS
# Local Network entitlement launchd grants, which a plain-shell rank does not
# have), so the domain is derived from /dev/console rather than from whoever
# invoked this — the primary caller is root, mid-activation.
#
# Exit codes:
#   0  LIVE          the rank agent reports state = running
#   1  NOT LIVE      the agent is loaded and stopped, or not loaded at all
#   2  UNDETERMINED  there is no GUI launchd domain to ask
#
# UNDETERMINED is a distinct answer on purpose. "Nobody is logged in" is not
# "the rank is stopped" — it is a question that could not be put — and a caller
# deciding what to do about a rank it cannot see must be able to tell those
# apart. In practice no rank can be running without the GUI domain that hosts
# it, so callers may treat 2 as not-clustered; they must SAY SO in their own
# log rather than silently folding it into 1 here.
#
# Every branch logs. A guard that can change what the machine does and returns
# in silence is exactly the shape that hid a 14-minute halt.
#
# Environment (all seams, all defaulted — the tests stub the first two):
#   MLX_CLUSTER_LAUNCHCTL_BIN  launchctl path (default /bin/launchctl)
#   MLX_CLUSTER_RANK_LABEL     rank agent label (default dev.mlx-cluster.rank;
#                              the canonical definition is nix-ai's rankLabel)
#   MLX_CLUSTER_GUI_UID        override the console-user uid

label="${MLX_CLUSTER_RANK_LABEL:-dev.mlx-cluster.rank}"
launchctl_bin="${MLX_CLUSTER_LAUNCHCTL_BIN:-/bin/launchctl}"
uid="${MLX_CLUSTER_GUI_UID:-$(/usr/bin/stat -f %u /dev/console 2> /dev/null || echo '')}"

log() { echo "mlx-cluster-rank-live: $*" >&2; }

# uid 0 on /dev/console is the loginwindow/no-session state, not a root GUI
# session, so it is the same answer as an unreadable console: nothing to ask.
if [ -z "$uid" ] || [ "$uid" = "0" ]; then
  log "UNDETERMINED — no console user, so there is no GUI launchd domain that could be running $label"
  exit 2
fi

if ! "$launchctl_bin" print "gui/$uid" > /dev/null 2>&1; then
  log "UNDETERMINED — no gui/$uid launchd domain (uid $uid is not logged in)"
  exit 2
fi

# Matched in the shell rather than piped through grep: this is the one
# statement the whole gate turns on, and it must not be able to answer "not
# running" because a binary was missing from PATH. A failed pipeline element
# looks exactly like a stopped rank, which is the wrong way for a guard to fail.
state="$("$launchctl_bin" print "gui/$uid/$label" 2> /dev/null || true)"
case "$state" in
  *'state = running'*)
    log "LIVE — $label is running in gui/$uid"
    exit 0
    ;;
esac

log "NOT LIVE — $label is not running in gui/$uid"
exit 1
