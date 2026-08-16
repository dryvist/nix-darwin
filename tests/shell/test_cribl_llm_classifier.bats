#!/usr/bin/env bats

MANAGER_LOG_PATTERN='^(\[(DEBUG|INFO|WARN|ERROR)\] |time=[^ ]+ level=(DEBUG|INFO|WARN|ERROR) |[0-9]{4}[/][0-9]{2}[/][0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})'
CRIBL_CONFIG="$BATS_TEST_DIRNAME/../../hosts/common/cribl.nix"

# Mirrors the pipeline eval: __inputId is checked FIRST (cluster logs share
# the llm_logs pipeline with the model-server logs but are a third, unrelated
# shape), then the manager/worker content regex as before.
classify() {
  local raw="$1" input_id="${2:-in_llm_logs}"
  if [[ "$input_id" == *cluster* ]]; then
    echo "mlx:cluster"
  elif [[ "$raw" =~ $MANAGER_LOG_PATTERN ]]; then
    echo "llamaswap"
  else
    echo "mlx:model-server"
  fi
}

@test "production classifier checks __inputId before content, then defaults to MLX workers" {
  run grep -F \
    "value: \"String(__inputId).includes('cluster') ? 'mlx:cluster' : _raw.match(/^(\\\\[(DEBUG|INFO|WARN|ERROR)\\\\] |time=[^ ]+ level=(DEBUG|INFO|WARN|ERROR) |[0-9]{4}[/][0-9]{2}[/][0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/) ? 'llamaswap' : 'mlx:model-server'\"" \
    "$CRIBL_CONFIG"
  [ "$status" -eq 0 ]
}

@test "manager record shapes remain llamaswap" {
  for line in \
    "[INFO] manager lifecycle" \
    "[WARN] manager lifecycle" \
    "time=2026-07-23T12:00:00Z level=ERROR manager lifecycle" \
    "2026/07/23 12:00:00 manager lifecycle"; do
    run classify "$line"
    [ "$status" -eq 0 ]
    [ "$output" = "llamaswap" ]
  done
}

@test "MLX worker headers and continuations remain mlx:model-server" {
  for line in \
    "2026-07-23 12:00:00,123 - DEBUG - structural marker" \
    $'\t\"field\": \"sanitized\"' \
    "}" \
    "]" \
    "Traceback (most recent call last):" \
    $'  File \"sanitized.py\", line 1, in sanitized' \
    "RuntimeError: sanitized"; do
    run classify "$line"
    [ "$status" -eq 0 ]
    [ "$output" = "mlx:model-server" ]
  done
}

@test "cluster-watcher/rank input lands as mlx:cluster regardless of content shape" {
  for line in \
    "cluster-link: HALTED (peer-absent) — rank starts suppressed" \
    "cluster-link: HEARTBEAT tick 14820 — link up, rank none, wired 53GiB" \
    "2026-08-16 08:19:47,759 - INFO - Prompt Cache: 0 sequences, 0.00 GB"; do
    run classify "$line" "in_cluster_logs"
    [ "$status" -eq 0 ]
    [ "$output" = "mlx:cluster" ]
  done
}
