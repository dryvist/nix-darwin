# Nix Dependencies Synchronization

## Rule: Dryvist Inputs Move Only Through Pull Requests

**Scope**: Flake inputs from `github:dryvist/*`.

Each dryvist input names a floating major tag: `github:dryvist/<repo>?ref=vN`.
`flake.lock` holds the exact revision. No input tracks `main`, `develop`, or "latest".

**Private repos** (explicitly excluded from sync rule):
- Any repositories marked as private in GitHub are completely ignored
- Private repos are not referenced in this rule or any sync processes

## Enforcement

### Pull requests (CI)

- **`deps-flake-lock.yml`** is the only writer of `flake.lock`. It opens its pull request on `chore/flake-lock`.
- **Scheduled** (weekly): relocks every input except dryvist inputs.
- **Release dispatch** (`update-flake-input`): relocks only the named dryvist input and classifies the bump
  (patch, minor, major) from the release tags.
- **Manual**: `gh workflow run deps-flake-lock.yml --repo dryvist/nix-darwin`.

### Merge rules

- **Dryvist patch bump**: auto-merges after the Merge Gate is green.
- **Dryvist minor or major bump**: never auto-merges. A person merges it.
- **`nixpkgs*` move**: never auto-merges. The pull request is labelled `needs-review`.

### Manual (full rebuild)

```bash
/flake-rebuild
```

This command:
1. Syncs main branch
2. Creates feature branch `chore/flake-update-YYYY-MM-DD`
3. Runs `nix flake update`
4. Runs quality checks (fmt, statix, deadnix, flake check)
5. Rebuilds system to validate all changes
6. Creates a pull request. The merge rules above apply.

## Related Files

- `.github/workflows/deps-flake-lock.yml` — Relock workflow: scheduled, release dispatch, and manual
- `renovate.json5` — Renovate config. Renovate does not write `flake.lock`.
- `flake.nix` — Input declarations
- `flake.lock` — Locked revisions (written only by `deps-flake-lock.yml`)
- `/flake-rebuild` command — Manual full update + rebuild trigger
