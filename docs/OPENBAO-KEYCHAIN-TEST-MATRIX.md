# OpenBao Keychain Test Matrix

Manual verification checklist for `programs.openbao-keychain`
(`modules/darwin/apps/openbao-keychain.nix`). `nix flake check` only proves
the module evaluates — it does **not** prove the keychain gets created
correctly, the resolver LaunchAgent runs when expected, or that a login
session actually sees the published env vars. Every scenario below must be
run by hand on real hardware before this is trusted as "autonomous, zero
prompts" for OpenBao secret access.

## Why this exists

An adversarial review of the wider OpenBao autonomous-secrets effort flagged
that a GUI-unlocked user keychain is **not** a machine-wide secret service: a
`LaunchDaemon`, an SSH-only session, or a pre-login job may not see the same
unlocked-keychain state a logged-in Aqua session does. This module is
deliberately built as a **user LaunchAgent** (never a `LaunchDaemon`) for
exactly that reason — but the claim still needs proving, not assuming.

## Prerequisites

- `sudo darwin-rebuild switch --flake .` has been run with this module
  enabled (`programs.openbao-keychain.enable = true;` — already set for both
  `macbook-m4` and `mac-studio` hosts).
- At least one domain has a real (or test) `role_id`/`secret_id` loaded into
  `openbao.keychain-db`, e.g.:

  ```sh
  security add-generic-password -s "openbao" -a "bao_addr" \
    -w "https://openbao.example.internal" \
    ~/Library/Keychains/openbao.keychain-db
  security add-generic-password -s "openbao/observability" -a "role_id" \
    -w "<test-value>" ~/Library/Keychains/openbao.keychain-db
  security add-generic-password -s "openbao/observability" -a "secret_id" \
    -w "<test-value>" ~/Library/Keychains/openbao.keychain-db
  ```

## Checklist

Record each scenario's result inline: ☐ not yet run / ☑ pass / ☒ fail (with a
note on what actually happened). Scenarios 4 and 5 are the ones most likely
to surprise — don't assume, observe.

### 1. Fresh login, keychain locked — ☐

Log out, log back in. Do NOT unlock `openbao.keychain-db`.

Expected: `launchctl print
gui/$(id -u)/com.nix-darwin.openbao-keychain-resolver` shows it ran;
`~/Library/Logs/openbao-keychain-resolver/resolver.error.log` shows
"not found" warnings (skipped, not crashed); `printenv BAO_ADDR` in a NEW
terminal is empty.

### 2. Unlock, then run manually — ☐

Unlock the keychain (Keychain Access.app or `security unlock-keychain
openbao.keychain-db`). Run `launchctl kickstart -k
gui/$(id -u)/com.nix-darwin.openbao-keychain-resolver`. Open a NEW terminal.

Expected: `printenv BAO_ADDR` and `printenv OBSERVABILITY_VAULT_ROLE_ID`
show the values just loaded.

### 3. RunAtLoad after reboot — ☐

Fully reboot (note whether the keychain re-locks on reboot regardless — it
may). Log in.

Expected: resolver fires at login (`RunAtLoad`); check the log timestamp
matches login time.

### 4. Sleep/wake — ☐

With the keychain unlocked and env vars published, put the Mac to sleep,
then wake it. Open a NEW terminal.

Expected: env vars from before sleep are STILL visible (a LaunchAgent's
`launchctl setenv` calls persist in the launchd session across sleep/wake;
only a reboot or logout clears them) — confirm this is actually true, not
assumed.

### 5. Over SSH — ☐

SSH into this Mac from another machine while the GUI session is logged in
and env vars are published.

Expected: unknown — SSH sessions are a DIFFERENT launchd domain in some
macOS configurations, so this is the scenario most likely to fail. Document
whatever the actual result is, don't assume either way.

### 6. Before GUI login (no session) — ☐

Reboot and stop at the login window (do not log in). From another machine,
check via SSH or physical access whether the resolver ran at all.

Expected: FAIL/not run — a LaunchAgent only starts once its owning user's
Aqua session exists. This confirms the documented limitation: jobs needing
pre-login access are out of scope for this keychain path and must use the
Linux-guest-style pattern instead.

### 7. 72-hour boundary — ☐

Unlock the keychain; note the time. Wait until 72h have elapsed without
unlocking it again (or temporarily lower `security set-keychain-settings -t
<seconds>` for a faster test, then restore). Run the resolver again after
the boundary.

Expected: reads fail (keychain auto-locked); resolver logs warnings and
does not publish stale/wrong values; no crash.

### 8. Consumer round-trip — ☐

With env vars published (scenario 2), run an `ansible-playbook` command
from a NEW terminal in the same session that touches `openbao_secrets`.

Expected: the Ansible role picks up `OBSERVABILITY_VAULT_ROLE_ID`/
`_SECRET_ID` via `lookup('env', ...)` with zero prompts.

## Recording results

Update each scenario's ☐/☑/☒ above and note the actual behavior for
scenarios 4 and 5 in particular. Any FAIL should be filed as a follow-up
before this module is relied on for production OpenBao secret delivery.
