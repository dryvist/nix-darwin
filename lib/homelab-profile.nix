# nix-ai maintainer profile — homelab context
#
# Split out of lib/user-config.nix to keep that file under the repository's
# file-size gate (see .file-size.yml). Pure static data, consumed through
# `userConfig.homelab` exactly as before.
#
# Takes the identifiers it composes from as arguments so no domain or handle
# is re-spelled here; lib/user-config.nix owns those definitions.

{ fullName, docsHost }:

# Trusted-infrastructure prose for Claude auto-mode, so routine cross-repo,
# cloud, and homelab actions are not flagged as exfiltration.
{
  enable = true;
  environmentRules = [
    "Single-developer personal homelab plus day-job (Splunk/Cribl architect). Public docs map: https://${docsHost} (source github.com/${fullName}/docs) covers Infrastructure, Nix ecosystem, AI development, Observability, Security, and Tools surfaces."
    "Workspace layout: each repo is a clone on its default branch. Create an isolated worktree for feature work via the AI tool's native mechanism (Claude's EnterWorktree, which lands worktrees under .claude/worktrees/). Never run `git worktree add` into a path inside the repo's working tree — that pollutes the main checkout; place any manual worktree as a sibling of the clone, never a child."
    "Cloud: AWS via aws-vault profiles (terraform-aws, terraform-aws-bedrock); Proxmox cluster on the home LAN (terraform-proxmox plus ansible-proxmox-*). No multi-tenant production."
    "Secrets stores: Doppler provides AI/MCP keys through locally selected project/configuration; macOS Keychain (ai-secrets keychain holds ANTHROPIC_API_KEY etc.; elevate-access keychain holds the break-glass OPENBAO_TOKEN); OpenBao mints GitHub tokens on demand (ephemeral GitHub App installation tokens via the openbao-github-creds credential helper — the old GH_PAT keychain tiers are retired) and short-lived AWS STS creds; Mozilla SOPS handles at-rest encryption; Bitwarden vault plus Bitwarden Secrets Manager. No long-lived AWS keys — OIDC handles CI."
    "AI runtimes: local MLX server on this Mac (mlx-server devenv shell); Claude / Codex / Gemini / Copilot CLIs all routed through local dev shells; HuggingFace CLI handles model management."
    "Observability stack: OpenTelemetry instrumentation → Cribl Stream → Splunk Enterprise (homelab). splunk-dev devenv shell on local Splunk work."
    "Self-hosted runners: GitHub Actions self-hosted RunsOn runners labeled per the ${fullName}/.github v3 catalog. Jobs targeting RunsOn labels are routine."
    "Container deployment: LXC on Proxmox is the default in production homelab workloads. Docker only on vendor-locked images that require it (high-throughput network traffic must never flow through Docker's virtualized networking)."
    "Nix-first: nix-darwin (macOS), nix-home (cross-platform user env), nix-ai (AI tooling), nix-devenv (reusable dev shells plus flakeModules.dev-hygiene), nix-claude-code (Claude Code declarative module). Flakes-only — never use nix-env."
    "Pre-commit, linting, format: pre-commit hooks come from nix-devenv.flakeModules.dev-hygiene in Nix repos. zizmor policy from dryvist/.github (trusted publishers: actions/*, DeterminateSystems/*, googleapis/* may use ref-pins; everything else requires hash-pins)."
  ];

  # Auto-permit rules for actions whose real access control lives outside the
  # classifier, so it does not re-litigate a boundary something else enforces.
  allowRules = [
    "OpenTofu / Terraform in the homelab IaC repos — `tofu`/`terraform` init, plan, apply (including `-auto-approve`), refresh, import, and state list/show/rm/mv, including when wrapped in `doppler run`, `sops exec-env`, and `nix develop … --command bash -c '…'` — is operator-authorized infrastructure work. State backend and provider auth already gate what a run can touch; allow without confirmation."
    "OpenBao (BAO_ADDR/VAULT_ADDR) API interactions at every privilege tier — AppRole login, KV read and write, and admin/`sys` operations, via `curl`, the `bao`/`vault` CLI, or inside `doppler run` wrappers — are allowed without confirmation. OpenBao's own AppRole policies enforce access separation and reject unauthorized requests; the auto-mode classifier is not the guard here."
  ];
}
