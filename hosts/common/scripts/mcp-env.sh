# mcp-env <server> -- <command> [args...]
#
# nix-ai's programs.aiMcp.envLauncher: supplies a credentialed MCP server's
# env_vars for the running account, then execs the server.
#
# An account with its own AppRole secret-zero file reads its own
# apps/<account> document. Every other account takes secret-zero from
# `doppler run`, then reads the server's OpenBao fields when MCP_ENV_TABLE
# lists the server, or the Doppler values alone when it does not.
server="${1:?usage: mcp-env <server> -- <command> [args...]}"
shift
if [ "${1:-}" = "--" ]; then
  shift
fi

account="$(basename "$HOME")"
env_file="$HOME/.openbao/${account}.env"
if [ -f "$env_file" ]; then
  exec openbao-run --domain "$account" --env-file "$env_file" --secrets "apps/${account}" -- "$@"
fi

# MCP_ENV_TABLE lines: <server> <approle domain> <ENV=path#field>...
while read -r name domain rest; do
  [ "$name" = "$server" ] || continue
  read -ra refs <<<"$rest"
  secret_args=()
  for ref in "${refs[@]}"; do
    secret_args+=(--secret "$ref")
  done
  exec doppler run -p "$MCP_ENV_DOPPLER_PROJECT" -c "$MCP_ENV_DOPPLER_CONFIG" -- \
    openbao-run --domain "$domain" "${secret_args[@]}" -- "$@"
done <<<"$MCP_ENV_TABLE"

exec doppler run -p "$MCP_ENV_DOPPLER_PROJECT" -c "$MCP_ENV_DOPPLER_CONFIG" -- "$@"
