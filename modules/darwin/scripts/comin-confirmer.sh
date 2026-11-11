# shellcheck shell=bash
# Confirm a waiting comin deployment only while the cluster rebuild gate allows activation.
#
# comin's deploy confirmer stays in `manual` mode and this job runs on an interval. When a generation
# waits for deploy confirmation, the job runs the cluster rebuild gate, the same check activation runs
# first:
#   - the gate allows: `comin confirmation accept`, logged with the gate's verdict;
#   - the gate refuses: nothing is confirmed, the refusal is logged, and the generation keeps waiting
#     for the next run.
# A comin that cannot report its state gets nothing confirmed. Every decision is one log line.
#
# Environment:
#   CLUSTER_REBUILD_GATE_BIN  path to cluster-rebuild-gate (injected by the module; a test seam otherwise)

gate="${CLUSTER_REBUILD_GATE_BIN:?CLUSTER_REBUILD_GATE_BIN not set}"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
one_line() { tr '\n' ' ' <<< "$1" | sed 's/[[:space:]]*$//'; }

if ! status="$(comin status --json 2>&1)"; then
  echo "$(ts) comin-confirmer: comin state unreadable; confirming nothing: $(one_line "$status")"
  exit 0
fi

if ! submitted="$(jq -r '.deploy_confirmer.submitted // ""' <<< "$status" 2> /dev/null)"; then
  echo "$(ts) comin-confirmer: comin state is not JSON; confirming nothing."
  exit 0
fi

[ -n "$submitted" ] || exit 0

if verdict="$("$gate" 2>&1)"; then
  echo "$(ts) comin-confirmer: CONFIRMING generation $submitted: $(one_line "$verdict")"
  comin confirmation accept
else
  echo "$(ts) comin-confirmer: REFUSING generation $submitted until the next check: $(one_line "$verdict")"
fi
