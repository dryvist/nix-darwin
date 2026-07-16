# Allow uv-managed CPython interpreters through the macOS application firewall.
#
# The JACCL rendezvous listener binds the Thunderbolt link address
# (non-loopback), so the application firewall filters it. uv-managed CPython
# is ad-hoc / linker-signed ("Identifier=-"), which the firewall's
# "automatically allow signed software" setting does NOT cover — inbound SYNs
# are dropped silently and the worker rank times out (errno 60) while ping and
# LISTEN both look healthy. Allow each interpreter explicitly; --add and
# --unblockapp are idempotent, so re-running on every activation is safe and
# self-heals across interpreter version bumps.
: "${CLUSTER_USER_HOME:?CLUSTER_USER_HOME must be set (injected by cluster-link-prep.nix)}"
SFW=/usr/libexec/ApplicationFirewall/socketfilterfw
for py in "$CLUSTER_USER_HOME"/.local/share/uv/python/cpython-*/bin/python3*; do
  [ -x "$py" ] || continue
  # stdout is success noise; stderr stays visible in the activation log.
  "$SFW" --add "$py" > /dev/null || true
  "$SFW" --unblockapp "$py" > /dev/null || true
  echo "cluster-alf-allow: allowed $py"
done
