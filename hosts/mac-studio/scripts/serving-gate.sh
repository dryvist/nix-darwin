#!/usr/bin/env bash
# Post-rebuild serving gate for the Studio.
#
# A rebuild restarts dev.mlx-model-server, dropping any in-flight completion.
# Hermes (hermes-gateway, in its own LXC — NOT on this host) rides those
# completions, and its brain-watchdog pauses and auto-resumes the cron fleet on
# upstream failure, so a clean bounce recovers by itself. What does not recover
# by itself is serving coming back degraded, and this host has two documented
# ways for that to happen:
#
#   1. Orphaned workers. llama-swap spawns engines detached, so a proxy restart
#      can leave a worker holding the port; replacements die "address already in
#      use" and every completion 429s.
#   2. A wedged scheduler, where completions return HTTP 200 with zero tokens.
#
# Both are invisible to a status-code check — /v1/models stays 200 through
# them — so this gate requires a REAL completion with completion_tokens >= 1.
#
# The probe sends the same sampling params as production traffic. Bare probes
# that omit them previously TRIGGERED the wedge by letting the engine batch
# processor-carrying and processor-free requests together.
#
# This deliberately does NOT restart Hermes. Hermes lives on another host;
# reaching across from here would be the SSH-into-a-live-guest pattern the
# estate forbids, would need a standing cross-host credential on this Mac, and
# would fail activation whenever that guest is unreachable. When a serving
# change requires clearing Hermes' in-process state, the sanctioned path is an
# `--tags hermes_agent` converge, run from where converges run.
#
# Warns rather than failing: activation has already happened by the time this
# runs, so a non-zero exit would report a half-applied system without
# un-breaking anything.

set -u

PORT="${SERVING_GATE_PORT:-11434}"
BASE="http://127.0.0.1:${PORT}"
SLEEP="${SERVING_GATE_SLEEP:-15}"
# Measured, not guessed: a cold llama-swap model swap on this host exceeded 90s
# and completed under 120s. 180 leaves headroom for the larger resident model.
TIMEOUT="${SERVING_GATE_TIMEOUT:-180}"
# HARD total budget. This runs inside activation, so an unbounded retry loop
# would hang a rebuild — naive attempt-counting with this timeout could block
# for ~20 minutes. The deadline is what actually bounds the work; attempts just
# stop early once it passes. 360s fits two full cold-swap attempts with room to
# spare, and a wedged engine is not going to un-wedge itself in minute nineteen.
DEADLINE_SECS="${SERVING_GATE_DEADLINE:-360}"

# /usr/bin/curl, not a nixpkgs curl: macOS Local Network privacy denies
# non-platform binaries LAN access in some launchd contexts. Loopback is exempt
# today, but the hardcoded platform binary is the estate rule and costs nothing.
CURL=/usr/bin/curl

model="$("$CURL" -sS --max-time 15 "${BASE}/v1/models" 2>/dev/null |
  jq -r '.data[0].id // empty' 2>/dev/null)"

if [ -z "${model}" ]; then
  echo "[serving-gate] WARN: ${BASE}/v1/models returned no model; serving may still be starting" >&2
  exit 0
fi

started="$(date +%s)"
attempt=0
while :; do
  attempt=$((attempt + 1))
  toks="$("$CURL" -sS --max-time "${TIMEOUT}" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"ok\"}],\"max_tokens\":1,\"repetition_penalty\":1.05}" \
    "${BASE}/v1/chat/completions" 2>/dev/null |
    jq -r '.usage.completion_tokens // 0' 2>/dev/null)"

  if [ "${toks:-0}" -ge 1 ]; then
    echo "[serving-gate] OK: ${model} returned ${toks} token(s) after ${attempt} attempt(s), $(( $(date +%s) - started ))s"
    exit 0
  fi

  elapsed=$(( $(date +%s) - started ))
  # Check the deadline against elapsed + the next attempt's worst case, so we
  # never start a request that would blow past it.
  if [ "$(( elapsed + SLEEP + TIMEOUT ))" -gt "${DEADLINE_SECS}" ]; then
    break
  fi
  # A cold engine legitimately takes time to load weights; retry before judging.
  sleep "${SLEEP}"
done

echo "[serving-gate] WARN: ${model} never returned a token (${attempt} attempts, $(( $(date +%s) - started ))s)." >&2
echo "[serving-gate]       Orphaned worker or wedged scheduler. Diagnose with:" >&2
echo "[serving-gate]         lsof -nP -iTCP:${PORT} -sTCP:LISTEN" >&2
echo "[serving-gate]         ps -eo pid,ppid,command | grep 'mlx_lm.server'" >&2
echo "[serving-gate]       Remedy is pkill of the worker tree — NOT launchctl kickstart -k," >&2
echo "[serving-gate]       which is what CREATES the orphan." >&2
exit 0
