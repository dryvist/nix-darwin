# Security Alert Triage

When code scanning alerts appear in GitHub, triage them according to this framework.

## Python Logging Alerts

Check if the flagged logging actually reveals secrets.

### FALSE POSITIVE (dismiss as "false positive")

- **Slack/Discord channel IDs**: Public workspace identifiers, not secrets
  - Example: Logging channel ID like `C1234567890`
- **Configuration metadata**: Key names, not values
  - Example: Logging `"keychain_key": "SLACK_CHANNEL_ID_nix-darwin"` (metadata about where the value came from)
- **Operational data**: Status strings, counts, ratios
  - Example: Logging `"status": "ok"` or `"issue_count": 42`

### WON'T FIX (dismiss as "won't fix" for credential helpers)

Scripts whose purpose is to output secrets for headless authentication:

- `bws_helper.py` - Retrieves secrets from Bitwarden for use in CI/CD
- `get-api-key.py` - Retrieves OAuth tokens for Claude authentication

These scripts are designed to output secrets because that's their function.
The output is piped directly to environment variables by callers, not logged.

### REQUIRES FIX

- Actual API keys, OAuth tokens, passwords being logged outside credential helpers
- Test-only files that unintentionally expose secrets
- Any logging that bypasses secure credential handling

## GitHub Actions Permissions Alerts

Always add explicit `permissions` blocks.

### Standard Permission

Most workflows only need to read repository contents:

```yaml
permissions:
  contents: read
```

Add this to workflows that:

- Check out code
- Read files from the repository
- Run linters, validators, or build steps
- Don't write to the repository

### Multiple Permissions

If a workflow needs more permissions, add them explicitly:

```yaml
permissions:
  contents: read
  pull-requests: read
```

Examples:

- Workflows that read PR metadata need `pull-requests: read`
- Workflows that write checks need `checks: write`
- Workflows that post comments need `pull-requests: write`

### Reusable Workflows

Reusable workflows (with `on: workflow_call`) inherit permissions from callers.
Still add explicit permissions to be defensive:

```yaml
on:
  workflow_call:

permissions:
  contents: read

jobs:
  ...
```

## Unpinned Action Tags (`actions/unpinned-tag`)

The CodeQL `actions/unpinned-tag` query flags any third-party `uses:` on a version
tag instead of a commit SHA. **Do not blanket-SHA-pin in response** — that contradicts
this repo's pinning policy, canonical in [`.github/zizmor.yml`](../../.github/zizmor.yml)
(`unpinned-uses: disable`): *trusted actions use version tags; hash pinning is reserved
for untrusted or lesser-known actions only.*

`actions/unpinned-tag` is an **extended-only** query (it lives in
`actions-security-extended.qls`, not the base suite). The org standard is CodeQL
default setup on the **`default` query suite** across all public repos, so this query
does not run and these alerts should not appear. That standard is org governance in
[`dryvist/tofu-github`](https://github.com/dryvist/tofu-github). If an
`actions/unpinned-tag` alert *does* surface, the repo's default setup has drifted onto
the `extended` suite — fix the suite, do not SHA-pin trusted actions. Classify the
flagged action first.

### Trusted — keep on the major version tag (`@vN`)

Never SHA-pin these; they belong on major tags:

- GitHub first-party: `actions/*`, `github/*`
- `DeterminateSystems/*` (e.g. `determinate-nix-action`)
- `anthropics/*` (e.g. `claude-code-action`)
- `nix-community/*` (e.g. `cache-nix-action`)
- `dorny/*` (e.g. `paths-filter`)

### Untrusted / individual maintainer — SHA-pin

Pin to a full commit SHA with the tag retained as a Renovate-managed `# vN` comment
(Renovate keeps the SHA current from the comment):

- `re-actors/alls-green`
- `peter-evans/create-pull-request`
- any other individual account or lesser-known action

This mirrors the cross-repo dependency trust-tier rule in
`dryvist/ai-assistant-instructions` — align with it rather than re-deriving a convention.

## Other Alerts

Refer to SECURITY.md for policy on alerts not covered here.
When in doubt, ask for guidance in the PR review.
