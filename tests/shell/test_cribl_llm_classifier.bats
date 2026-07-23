#!/usr/bin/env bats

MANAGER_LOG_PATTERN='^(\[(DEBUG|INFO|WARN|ERROR)\] |time=[^ ]+ level=(DEBUG|INFO|WARN|ERROR) |[0-9]{4}[/][0-9]{2}[/][0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})'
CRIBL_CONFIG="$BATS_TEST_DIRNAME/../../hosts/common/cribl.nix"

classify() {
  if [[ "$1" =~ $MANAGER_LOG_PATTERN ]]; then
    echo "llamaswap"
  else
    echo "mlx:model-server"
  fi
}

@test "production classifier identifies manager records and defaults to MLX workers" {
  run grep -F \
    "value: \"_raw.match(/^(\\\\[(DEBUG|INFO|WARN|ERROR)\\\\] |time=[^ ]+ level=(DEBUG|INFO|WARN|ERROR) |[0-9]{4}[/][0-9]{2}[/][0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/) ? 'llamaswap' : 'mlx:model-server'\"" \
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
