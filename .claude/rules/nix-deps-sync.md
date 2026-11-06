# Nix Dependencies Synchronization

## Rule: Dryvist Inputs Move Only Through Pull Requests

**Scope**: Flake inputs from `github:dryvist/*`.

Each dryvist input names a floating major tag: `github:dryvist/<repo>?ref=vN`.
`flake.lock` holds the exact revision. No input tracks `main`, `develop`, or "latest".

**Private repos** (explicitly excluded from sync rule):
- Any repositories marked as private in GitHub are completely ignored
- Private repos are not referenced in this rule or any sync processes

## Who writes `flake.lock`

- **Renovate** (`github>JacobPEvans/.github:renovate-nix`): one Saturday `lockFileMaintenance` PR that relocks
  this repository's own inputs, plus tag bumps for inputs that name a release tag.
- **`review-deps.yml`**: reviews lock-file diffs and enables auto-merge.
- Shared roots in this repo's lock (`nixpkgs`, `nixpkgs-unstable`, `home-manager`, `darwin`) only feed CI. The
  deployed hosts override them from the top-level flake's soaked pins, so a revision here never reaches a Mac.

## Manual (full rebuild)

```bash
/flake-rebuild
```

This command:
1. Syncs main branch
2. Creates feature branch `chore/flake-update-YYYY-MM-DD`
3. Runs `nix flake update`
4. Runs quality checks (fmt, statix, deadnix, flake check)
5. Rebuilds system to validate all changes
6. Creates a pull request.

## Related Files

- `renovate.json5` — Renovate config, including lock-file maintenance
- `.github/workflows/review-deps.yml` — Lock-file diff review and auto-merge
- `flake.nix` — Input declarations
- `flake.lock` — Locked revisions
- `/flake-rebuild` command — Manual full update + rebuild trigger
