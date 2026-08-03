#!/usr/bin/env bash
# Assert lib/hosts/mac-studio.nix's serveConcurrency matches
# dryvist/tofu-proxmox's pipeline_constants.serving.llm_concurrency.
#
# nix's flake evaluation is hermetic (no network access at build time), so it
# cannot derive this value from tofu-proxmox the way ansible-proxmox-ai does
# over the tofu_data.constants channel. This script is the mechanical
# substitute _llm-concurrency-parity.yml runs in CI: it fails loudly on
# drift instead of trusting the comment above serveConcurrency.
#
# Usage: check-llm-concurrency-parity.sh <mac-studio.nix path> <constants.tf path>
set -euo pipefail

nix_file="$1"
tofu_file="$2"

nix_value=$(grep -oE 'serveConcurrency = [0-9]+;' "$nix_file" | grep -oE '[0-9]+') || true
if [[ -z "$nix_value" ]]; then
  echo "::error::could not find 'serveConcurrency = N;' in $nix_file"
  exit 1
fi

# Restrict the search to the `serving = { ... }` block so a coincidental
# llm_concurrency elsewhere in the file can never match.
tofu_value=$(awk '/serving = {/{f=1} f{print} f && /}/{exit}' "$tofu_file" \
  | grep -oE 'llm_concurrency = [0-9]+' | grep -oE '[0-9]+') || true
if [[ -z "$tofu_value" ]]; then
  echo "::error::could not find pipeline_constants.serving.llm_concurrency in $tofu_file"
  echo "::error::has the value been promoted to dryvist/tofu-proxmox's main branch yet?"
  exit 1
fi

if [[ "$nix_value" != "$tofu_value" ]]; then
  echo "::error::LLM serving concurrency drift: $nix_file serveConcurrency=$nix_value" \
    "but dryvist/tofu-proxmox pipeline_constants.serving.llm_concurrency=$tofu_value." \
    "Raise both together — see the private serving-concurrency reference."
  exit 1
fi

echo "OK: serveConcurrency ($nix_value) matches tofu-proxmox's published serving.llm_concurrency."
