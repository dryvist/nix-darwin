# Shared OpenBao-backed credential/config providers
#
# Both hosts run the identical set of ambient, keychain-free OpenBao
# wrappers — secret-zero (VAULT_ADDR/BAO_ADDR + an AppRole) comes from
# `doppler run`, never a local keychain, and nothing is cached on disk.
# Declared once here, imported by hosts/common/default.nix, rather than
# duplicated per host; a host that needs a DIFFERENT subset would override
# the relevant option in its own file. See modules/darwin/apps/openbao-*.nix
# for each wrapper's implementation.

_:

{
  programs = {
    # `credential_process` for the tf-proxmox AWS profile.
    openbao-aws-creds.enable = true;

    # Ambient READ tokens, per-repo WRITE behind a claim/lease. The git
    # credential wiring lives in ./home.nix.
    openbao-github-creds.enable = true;

    # The slack-admin AppRole; token pair lives in OpenBao KV-v2, never on
    # disk.
    openbao-slack-creds.enable = true;

    # Env injector for interactive use. The llm-gate and maintenance-window
    # modules also enable this; the option merges.
    openbao-run.enable = true;
  };
}
