# sops-nix Secret Management
#
# Decrypts age-encrypted secrets from secrets/ to root-only files in /run/secrets
# at activation time. Root reads the age private key from the primary user's
# ~/.config/sops/age/keys.txt — root can access this path on macOS regardless of
# the 0600 mode because DAC does not restrict root.
#
# Key file:  ~/.config/sops/age/keys.txt  (generated once per machine, never committed)
# Public key in .sops.yaml                (committed to git)
# Encrypted secrets in secrets/           (committed to git, safe to be public)
# Decrypted secrets in /run/secrets/      (ephemeral, root:wheel 0400)
#
# Server-class extras: the github-runner PAT and HF token exist only on
# `class = "server"` hosts (the Studio) — the laptop never declares or
# decrypts them, so its closure and activation are untouched. (The llm-gate's
# secrets are not here at all — they come from Doppler at runtime.)

{
  config,
  lib,
  hostConfig,
  ...
}:

let
  userConfig = import ../../lib/user-config.nix;
  rootOnly = {
    owner = "root";
    group = "wheel";
    mode = "0400";
  };
  # The GitHub runner agent runs as the login user (Apple `container` is
  # per-user), so its PAT env-file must be readable by that user — consumed
  # via `container run --env-file` (modules/darwin/apps/github-runner-container.nix).
  userOnly = {
    owner = userConfig.user.name;
    group = "staff";
    mode = "0400";
  };
  # (isServer is normalized once in flake.nix mkHost.)
  inherit (hostConfig) isServer;
in
{
  sops = {
    age = {
      # Absolute path — expands at Nix eval time, not shell time, so root finds it
      keyFile = "${userConfig.user.homeDir}/.config/sops/age/keys.txt";
      generateKey = false;
      sshKeyPaths = [ ];
    };

    # Age-only. Disable GPG/SSH fallback to fail fast on misconfiguration.
    gnupg.sshKeyPaths = [ ];

    # Individual secret files — each decrypts to /run/secrets/<name>
    secrets = {
      # Cribl Edge enrollment credentials
      # Source: secrets/cribl-edge.yaml (age-encrypted, committed to git)
      CRIBL_ORG_ID = rootOnly // {
        sopsFile = ../../secrets/cribl-edge.yaml;
      };
      CRIBL_WORKSPACE_ID = rootOnly // {
        sopsFile = ../../secrets/cribl-edge.yaml;
      };
      CRIBL_TOKEN = rootOnly // {
        sopsFile = ../../secrets/cribl-edge.yaml;
      };
    }
    // lib.optionalAttrs isServer {
      # NOTE: the llm-gate (Caddy) secrets — bearer token, Route53 ACME creds,
      # AWS region — are deliberately NOT managed here. They live only in
      # Doppler and are injected into the gate at runtime via `doppler run`
      # (see modules/darwin/llm-gate.nix). Copying them into sops would
      # duplicate the source of truth and guarantee drift on rotation, and
      # Route53 management creds are too sensitive for a public repo even
      # age-encrypted.

      # GitHub Actions runner org PAT (fine-grained: org self-hosted-runners
      # RW only) — secrets/github-runner.yaml.
      GH_RUNNER_PAT = userOnly // {
        sopsFile = ../../secrets/github-runner.yaml;
      };

      # Hugging Face token — secrets/hf.yaml. Server-class hosts are
      # keychain-free for real secrets (portability directive 2026-07-02):
      # the zsh init reads this rendered path instead of the macOS keychain.
      # Tier-2 end state is OpenBao (JAC-153); sops is the declarative,
      # zero-prompt bridge that already rides the per-machine age keys.
      HF_TOKEN = userOnly // {
        sopsFile = ../../secrets/hf.yaml;
      };

      # NOTE: the Claude Code OAuth token is deliberately NOT managed here —
      # or anywhere on disk. It is too sensitive for this repo in any form
      # (even age-encrypted); its only stores are Doppler / GitHub Actions
      # secrets; local consumers rely on the claude CLI's own login-session
      # credentials instead.
    };

    # Rendered templates: assemble individual secrets into complete config
    # files consumed directly by their services (no wrapper scripts). The
    # llm-gate Caddyfile template lives in modules/darwin/llm-gate.nix with
    # the rest of that module's config.
    templates = {
      "cribl-edge.env" = rootOnly // {
        content = ''
          CRIBL_ORG_ID=${config.sops.placeholder."CRIBL_ORG_ID"}
          CRIBL_WORKSPACE_ID=${config.sops.placeholder."CRIBL_WORKSPACE_ID"}
          CRIBL_TOKEN=${config.sops.placeholder."CRIBL_TOKEN"}
        '';
      };
    }
    // lib.optionalAttrs isServer {
      # Consumed via `container run --env-file` by the gh-runner agent — the
      # vendor image's ACCESS_TOKEN input (PAT → registration token exchange
      # happens inside the image; UNSET_CONFIG_VARS scrubs it before jobs).
      "github-runner.env" = userOnly // {
        content = ''
          ACCESS_TOKEN=${config.sops.placeholder."GH_RUNNER_PAT"}
        '';
      };
    };
  };
}
