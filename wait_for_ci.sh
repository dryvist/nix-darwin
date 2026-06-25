#!/bin/bash
PR=$1
while true; do
  STATUS=$(gh pr view $PR --json statusCheckRollup --jq '[.statusCheckRollup[].status] | all(. == "COMPLETED")')
  if [ "$STATUS" == "true" ]; then
    gh pr view $PR --json mergeable,mergeStateStatus,reviewDecision,statusCheckRollup
    exit 0
  fi
  sleep 15
done
