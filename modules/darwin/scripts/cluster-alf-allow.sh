# Allow uv-managed CPython interpreters through the macOS application firewall.
#
# The JACCL rendezvous listener binds the Thunderbolt link address
# (non-loopback), so the application firewall filters it. uv-managed CPython
# is ad-hoc / linker-signed ("Identifier=-"), which the firewall's
# "automatically allow signed software" setting does NOT cover — inbound SYNs
# are dropped silently and the worker rank times out (errno 60) while ping and
# LISTEN both look healthy. Allow each interpreter explicitly through
# alf-allow-apps (idempotent add and unblock), so re-running on every
# activation is safe and self-heals across interpreter version bumps.
: "${CLUSTER_USER_HOME:?CLUSTER_USER_HOME must be set (injected by cluster-link-prep.nix)}"
interpreters=()
for py in "$CLUSTER_USER_HOME"/.local/share/uv/python/cpython-*/bin/python3*; do
  if [ -x "$py" ]; then interpreters+=("$py"); fi
done
if [ "${#interpreters[@]}" -gt 0 ]; then
  "${ALF_ALLOW_APPS:-alf-allow-apps}" "${interpreters[@]}"
fi
