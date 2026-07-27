# Legacy sops-nix Secret Management
#
# OpenBao is the general secret store. New SOPS entries are permitted only for
# trivial sensitive values that are owned exclusively by this repository and
# never consumed by another repository. SaaS/external credentials and shared
# homelab credentials belong in OpenBao, never SOPS.
#
# This module remains only while the GitHub runner and Hugging Face legacy
# consumers migrate to OpenBao. Do not add another external secret here.
#
# Key file:  ~/.config/sops/age/keys.txt  (generated once per machine, never committed)
# Public key in .sops.yaml                (committed to git)
# Encrypted secrets in secrets/           (committed to git, safe to be public)
# Decrypted secrets in /run/secrets/      (ephemeral, root:wheel 0400)
#
# The remaining server-only GitHub runner PAT and Hugging Face token are
# migration debt, not precedent. The llm-gate already reads OpenBao at runtime.

{
  config,
  lib,
  hostConfig,
  ...
}:

let
  userConfig = import ../../lib/user-config.nix;
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

    # Legacy external secrets. Each must move to an OpenBao runtime lookup;
    # this exception list may shrink but must not grow.
    secrets = lib.optionalAttrs isServer {
      # NOTE: the llm-gate (Caddy) secrets — bearer token, Route53 ACME creds,
      # AWS region — are deliberately NOT managed here. openbao-run reads
      # them from OpenBao when the gate starts (see modules/darwin/llm-gate.nix).
      # Copying them into SOPS would
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

    # The llm-gate has no SOPS template; it reads OpenBao at runtime.
    templates = lib.optionalAttrs isServer {
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
