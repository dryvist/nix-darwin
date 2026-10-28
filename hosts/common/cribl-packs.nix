# Released Cribl Edge pack pins for the macOS Edge (standalone GitOps config).
#
# Each pack is a fetchzip of its released .crbl (tar.gz) asset, pinned by the
# SRI hash of the unpacked tree. ./cribl.nix consumes this attrset three ways:
# `packs` (deployment, gated by the homelab-contracts catalog), worker-level
# pipelines and breakers, and exec command text. The pins hold no Cribl content;
# that lives in the pack repositories.
{ pkgs }:

{
  cc-edge-the-mac-pack-io = pkgs.fetchzip {
    url = "https://github.com/dryvist/cc-edge-the-mac-pack-io/releases/download/v0.5.0/cc-edge-the-mac-pack-io-v0.5.0.crbl"; # renovate: cc-edge-the-mac-pack-io
    extension = "tar.gz";
    hash = "sha256-s7K7G+ieqrUA87480ksjHDerhb3paJvSYbTX3h6mO0s=";
    stripRoot = false;
  };
  cc-edge-codex-io = pkgs.fetchzip {
    url = "https://github.com/dryvist/cc-edge-codex-io/releases/download/v0.1.1/cc-edge-codex-io-v0.1.1.crbl";
    extension = "tar.gz";
    hash = "sha256-EgPHvubxZ+ey1alAtPXIueInzMpMB5gdt8E8aGkUlF0=";
    stripRoot = false;
  };
  cc-edge-gemini-antigravity-io = pkgs.fetchzip {
    url = "https://github.com/JacobPEvans-personal/cc-edge-gemini-antigravity-io/releases/download/v0.4.1/cc-edge-gemini-antigravity-io-v0.4.1.crbl";
    extension = "tar.gz";
    hash = "sha256-VzRPBode10yLdDqmcaOhwWnTpUVmF10OwVkXZtyjGJ4=";
    stripRoot = false;
  };
  cc-edge-macos-diagnostic-reports-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-macos-diagnostic-reports-io/releases/download/v0.1.0/cc-edge-macos-diagnostic-reports-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-M9zG4nzb/hR+qZsn20OI6mBuEs7Ms94DvuU/riL7ftQ=";
    stripRoot = false;
  };
  cc-edge-macos-power-thermal-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-macos-power-thermal-io/releases/download/v0.1.0/cc-edge-macos-power-thermal-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-ZIgvMBzU+wT5z8URfynSt0cJC+7jrd8HZwg7lwHsLSo=";
    stripRoot = false;
  };
  cc-edge-macos-ws-monitor-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-macos-ws-monitor-io/releases/download/v0.1.0/cc-edge-macos-ws-monitor-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-oNMeQSIImjNbzxSxmLqazz6/f7vlgozzIFryFZVmW4E=";
    stripRoot = false;
  };
  cc-edge-ai-transcript-shared-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-ai-transcript-shared-io/releases/download/v0.1.0/cc-edge-ai-transcript-shared-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-SYKgftAnOgjUASrBvWzAaQApb3XLfFM6+JQOo4nz5k4=";
    stripRoot = false;
  };
  cc-edge-mlx-serving-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-mlx-serving-io/releases/download/v0.1.0/cc-edge-mlx-serving-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-lzI55b197G3VbkCB5Kdlxwol5QeuMT7ZF1nWFB0PUw0=";
    stripRoot = false;
  };
  cc-edge-macos-process-telemetry-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-macos-process-telemetry-io/releases/download/v0.1.0/cc-edge-macos-process-telemetry-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-1UBzCSxzv7qj0CBtOsb/8vJzqBIkPqht/xdtuWNtRKo=";
    stripRoot = false;
  };
  cc-edge-macos-firewall-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-macos-firewall-io/releases/download/v0.1.0/cc-edge-macos-firewall-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-vFA884aCw3k4osT494vSsd87ykw95nt16195YTr8g4s=";
    stripRoot = false;
  };
  cc-edge-macos-unified-logs-io = pkgs.fetchzip {
    url = "https://github.com/jpe-cribl/cc-edge-macos-unified-logs-io/releases/download/v0.1.0/cc-edge-macos-unified-logs-io-0.1.0.crbl";
    extension = "tar.gz";
    hash = "sha256-b08dmz2s1c7Sz56RGb9Pj1LFlgHU6BOi5deLNaqk4jc=";
    stripRoot = false;
  };
}
