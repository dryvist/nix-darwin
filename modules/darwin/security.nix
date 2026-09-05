# Security Configuration
#
# CRITICAL: This file contains security-sensitive settings.
# Changes here affect system-level permissions and should be reviewed carefully.
#
# Current security policies:
# - Passwordless sudo for Thunderbolt-RDMA / cluster troubleshooting commands
#   (enables unattended cluster bring-up recovery)
# - No passwordless sudo for darwin-rebuild/activate — a converge is a
#   deliberate, password-gated root action (feat/workstation-posture-hardening)
# - The one passwordless converge grant belongs to the automation account and
#   is declared with that account in modules/darwin/agent-identity.nix

{ lib, ... }:

let
  userConfig = import ../../lib/user-config.nix;

  # ==========================================================================
  # Cluster / RDMA launchd targets
  # ==========================================================================
  # The two-Mac Thunderbolt-RDMA cluster (see cluster-link-prep.nix) is
  # driven by launchd user agents under these label prefixes. `gui/501` is
  # ${userConfig.user.name}'s login-session domain (uid 501, the sole macOS
  # account on both hosts — launchd's gui/<uid> syntax needs the literal
  # numeric uid; it cannot be derived at sudoers-match time).
  clusterLaunchdTargets = [
    {
      domain = "gui/501";
      labelGlob = "dev.mlx-cluster.*";
    }
    {
      domain = "gui/501";
      labelGlob = "dev.mlx-model-server*";
    }
  ];

  # One NOPASSWD line per target/verb pair, all scoped to the cluster
  # label prefixes above — never a bare `launchctl` grant. The `kill`/`kickstart`
  # wildcards only widen the *signal*/flag, not the target label, so they cannot
  # reach a service outside these prefixes.
  #
  # `bootstrap` is the one verb that loads a plist FROM DISK as root, so its
  # path must never resolve to attacker-controlled content:
  #   - `system` daemons live in /Library/LaunchDaemons, which is root-owned
  #     (0755 root:wheel) — a user process cannot plant or symlink a plist
  #     there, so the anchored path glob can only match the real root daemons.
  #   - `gui/501` agents live in ~/Library/LaunchAgents, which IS user-writable
  #     (0700 ${userConfig.user.name}) — a passwordless-root bootstrap of that
  #     path would be a privesc. It is also unnecessary: those agents are
  #     RunAtLoad (home-manager bootstraps them at login) and the user can
  #     bootstrap them in their own gui/501 domain without root. So no
  #     bootstrap grant is emitted for user-agent targets.
  clusterLaunchdRules = lib.concatMapStrings (
    t:
    ''
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl kickstart -k ${t.domain}/${t.labelGlob}
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl bootout ${t.domain}/${t.labelGlob}
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl print ${t.domain}/${t.labelGlob}
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl kill * ${t.domain}/${t.labelGlob}
    ''
    + lib.optionalString (t.domain == "system") ''
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl bootstrap system /Library/LaunchDaemons/${t.labelGlob}
    ''
  ) clusterLaunchdTargets;

  # ==========================================================================
  # MLX model-server serving-restore ladder (INC-17083 / INC-17062)
  # ==========================================================================
  # Exact standalone-serving recovery target. nix-ai owns the label
  # (programs.mlx launchAgentLabel = "dev.mlx-model-server");
  # nix-ai itself addresses this plist as
  # ~/Library/LaunchAgents/<label>.plist (cluster-mode.nix CLUSTER_SERVER_PLIST),
  # so the path is derived from the home dir + label here, never a hardcoded
  # /Users literal. gui/501 = uid 501 (see the cluster block above).
  mlxServerLabel = "dev.mlx-model-server";
  mlxServerPlist = "${userConfig.user.homeDir}/Library/LaunchAgents/${mlxServerLabel}.plist";
in
{
  # ==========================================================================
  # Passwordless sudo for darwin-rebuild: REMOVED (feat/workstation-posture-hardening)
  # ==========================================================================
  # A NOPASSWD grant on darwin-rebuild/activate is a root primitive for
  # anyone who can run a shell as this user — including an AI assistant, or
  # anything that compromises it. `sudo darwin-rebuild switch` now prompts
  # for a password like any other root operation; cluster-recovery NOPASSWD
  # verbs below are unaffected.
  environment.etc = {
    # ==========================================================================
    # Passwordless sudo: Thunderbolt-RDMA / cluster troubleshooting
    # ==========================================================================
    # Purpose: let an autonomous agent inspect and converge the cluster-mode
    # Thunderbolt link and its launchd services without an interactive password
    # prompt, so unattended cluster bring-up recovery does not stall mid-run.
    #
    # Security considerations:
    # - launchctl access is scoped to the cluster label prefixes above
    #   (gui/501/dev.mlx-cluster.*, gui/501/dev.mlx-model-server*) — never a blanket
    #   `launchctl` grant. `bootstrap` (the only plist-loading verb) is granted
    #   ONLY for system-domain targets against the root-owned
    #   /Library/LaunchDaemons path (none currently declared); see the
    #   clusterLaunchdRules comment on why user-agent bootstrap is dropped.
    # - networksetup grant covers disabling/enabling the bridge0 network service —
    #   the root-cause fix for macOS re-enslaving the RDMA port into the
    #   Thunderbolt Bridge (mirrors the activation-script step so the operator can
    #   re-apply it at runtime without handing the step back to the user).
    # - ifconfig grants cover the operations that genuinely need root: managing the
    #   Thunderbolt Bridge itself (`bridge0 *` — detach `deletem` and `destroy` to
    #   clear stale bridge state) and bouncing a Thunderbolt port up/down during
    #   link recovery. Interface *reads* need no root, so plain `ifconfig enX`
    #   inspection is intentionally NOT granted. The `enX` grants are pinned to
    #   `en[0-9]*` with a fixed verb — no arbitrary trailing args — so they can
    #   neither reassign an address, change MTU, nor destroy an interface.
    #   Trade-off: `en[0-9]*` still covers the built-in en0/en1 ports (which
    #   Thunderbolt port carries the cable varies by plug, so its index cannot
    #   be pinned in a static pattern), but up/down on those is recoverable
    #   and non-destructive. `bridge0 *` is scoped to the single bridge interface
    #   the cluster owns.
    # - reboot is granted (added 2026-07-12 with explicit user approval) so the
    #   autonomous agent can clear a reboot-only RDMA/Protection-Domain wedge and
    #   let the reboot-continuity agent (claude-continuity.nix) resume the session.
    #   Only the two restart verbs are granted — `/sbin/reboot` and
    #   `/sbin/shutdown -r now` — never a bare `/sbin/shutdown` (which could halt
    #   or power the host off).
    # - FileVault caveat (corrected 2026-07-12 after a live self-reboot test): a
    #   plain `/sbin/reboot` does NOT auto-unlock FileVault. A FileVault host
    #   strands at the pre-boot unlock screen until the password is typed, so
    #   auto-login + continuity never fire (observed: MBP stranded ~45 min).
    #   `/usr/bin/fdesetup authrestart` is the verb that pre-authorizes the next
    #   boot's unlock; it is granted here so a *supervised* authrestart needs no
    #   sudo password. It is NOT sufficient for a fully unattended reboot on its
    #   own — `fdesetup authrestart` still requires a FileVault credential, and
    #   feeding that credential automatically (via `-inputplist`) is a separate
    #   security decision left to the user; this module deliberately neither
    #   stores nor feeds it. FileVault-OFF hosts (e.g. the Studio) already reboot
    #   unattended with `/sbin/reboot` alone.
    #
    # To disable: comment out or remove this entry.
    "sudoers.d/cluster-ops".text = ''
      # Allow ${userConfig.user.name} to run cluster/RDMA troubleshooting commands
      # without password. Generated by nix-darwin - do not edit manually
      ${clusterLaunchdRules}
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /usr/sbin/networksetup -setnetworkserviceenabled * off
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /usr/sbin/networksetup -setnetworkserviceenabled * on
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /sbin/ifconfig bridge0 deletem *
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /sbin/ifconfig bridge0 destroy
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /sbin/ifconfig en[0-9]* up
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /sbin/ifconfig en[0-9]* down
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /sbin/reboot
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /sbin/shutdown -r now
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /usr/bin/fdesetup authrestart
    '';

    # ==========================================================================
    # Passwordless sudo: MLX model-server serving-restore ladder
    # ==========================================================================
    # The standalone recovery ladder — bootout -> bootstrap -> kickstart — must
    # never stall on a password prompt in an
    # automation context (INC-17083 restore stalled exactly here; the same ladder
    # is the tail of the INC-17062 cluster-detach standalone-serving restore).
    #
    # These are gui/501 (the user's own login domain), so launchd does NOT
    # strictly require root: the user can bootout/bootstrap/kickstart their own
    # agents unprivileged. The grants exist so an automation context can run the
    # WHOLE ladder uniformly via `sudo -n` without some steps succeeding
    # unprivileged and others prompting.
    #
    # Exact argv forms only — no space-spanning globs (heeds issue #1770):
    # - bootout / kickstart -k target the exact label `dev.mlx-model-server`.
    #   These also match the broader `dev.mlx-model-server*` cluster-ops glob above, but
    #   are restated here in exact form so the restore ladder is a self-contained
    #   contract that survives any future narrowing of that glob (#1770).
    # - bootstrap gui/501 is the verb the cluster-ops block deliberately WITHHOLDS
    #   for user agents. It is safe to grant here because bootstrapping into the
    #   user's own gui/501 domain runs the agent as the domain owner (uid 501),
    #   NOT as root — so, unlike a system-domain bootstrap (which runs root
    #   daemons and is why that path is anchored to root-owned
    #   /Library/LaunchDaemons), this is not a privilege escalation: the user can
    #   already load their own agents. It is anchored to the exact MLX model-server
    #   plist path (not a `~/Library/LaunchAgents/*` directory glob), so it can
    #   only load that one known agent, never an arbitrary user-planted plist.
    #
    # To disable: comment out or remove this entry.
    "sudoers.d/mlx-serving-restore".text = ''
      # Allow ${userConfig.user.name} to run the MLX model-server serving-restore ladder
      # without password. Generated by nix-darwin - do not edit manually
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl bootout gui/501/${mlxServerLabel}
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl bootstrap gui/501 ${mlxServerPlist}
      ${userConfig.user.name} ALL=(ALL) NOPASSWD: /bin/launchctl kickstart -k gui/501/${mlxServerLabel}
    '';
  };
}
