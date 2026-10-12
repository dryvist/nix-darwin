# Shared OpenBao clients
#
# Both hosts run openbao-run and the Azure credential wrapper. Secret-zero and
# credential selections come from the caller's ambient environment.

_:

{
  programs = {
    openbao-azure-creds.enable = true;

    # Env injector for interactive use. The llm-gate and maintenance-window
    # modules also enable this; the option merges.
    openbao-run.enable = true;
  };
}
