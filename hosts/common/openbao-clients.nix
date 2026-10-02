# Shared OpenBao env injector
#
# Both hosts run openbao-run, the generic env injector: it reads its AppRole
# pair from the environment (for example a loaded .env file) and injects the
# requested secrets into one child process. Nothing is cached on disk.
# Credential helpers that name specific roles are supplied by the host
# wrapper, not this repo.

_:

{
  programs = {
    # Env injector for interactive use. The llm-gate and maintenance-window
    # modules also enable this; the option merges.
    openbao-run.enable = true;
  };
}
