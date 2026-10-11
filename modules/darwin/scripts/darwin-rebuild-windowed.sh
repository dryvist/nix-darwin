# shellcheck shell=bash
# darwin-rebuild-windowed: runs `darwin-rebuild switch` for this host only when
# every check below passes. Each check denies with a logged reason:
#
#   1. exactly one argument, a hostname of lowercase letters, digits and hyphens
#   2. the process runs as the trusted uid
#   3. the window socket and its directory are owned by the owner uid and are
#      writable by no group or other uid
#   4. the window socket answers auth/token/lookup-self. The request carries no
#      token: the proxy listening on the socket adds its own
#   5. the lookup-self response lists the ai-admin policy, names the
#      ai-admin-session role in meta.role_name, and reports a ttl above zero
#   6. the host is not clustered: link-state "up" together with peer-state.json
#      "armed": true. Missing state files mean not clustered; a file that cannot
#      be read, or holds an unexpected value, denies
#   7. then runs exactly: darwin-rebuild switch --flake <fixed ref>#<hostname> --refresh
#
# Every decision goes to syslog under the tag darwin-rebuild-windowed and to
# stderr. A denial exits 1; a run exits with darwin-rebuild's status. The
# wrapper revokes nothing and signals no process.
#
# writeShellApplication (modules/darwin/darwin-rebuild-windowed.nix) provides
# strict mode, PATH and the variables below. The shell tests set them to stubs.
#   DARWIN_REBUILD_WINDOWED_WINDOW_SOCKET       unix socket of the window proxy
#   DARWIN_REBUILD_WINDOWED_OWNER_UID           uid that owns the socket and its directory
#   DARWIN_REBUILD_WINDOWED_CLUSTER_STATE_DIR   directory holding link-state and peer-state.json
#   DARWIN_REBUILD_WINDOWED_DARWIN_REBUILD_BIN  darwin-rebuild executable
#   DARWIN_REBUILD_WINDOWED_CURL_BIN            curl executable for lookup-self
#   DARWIN_REBUILD_WINDOWED_LOGGER_BIN          logger executable
#   DARWIN_REBUILD_WINDOWED_TRUSTED_UID         uid that must run the script
#   DARWIN_REBUILD_WINDOWED_FLAKE_REF           flake (without #attr) the switch builds

hostname_re='^[a-z0-9-]+$'

window_socket="${DARWIN_REBUILD_WINDOWED_WINDOW_SOCKET:?not set}"
owner_uid="${DARWIN_REBUILD_WINDOWED_OWNER_UID:?not set}"
cluster_dir="${DARWIN_REBUILD_WINDOWED_CLUSTER_STATE_DIR:?not set}"
darwin_rebuild="${DARWIN_REBUILD_WINDOWED_DARWIN_REBUILD_BIN:?not set}"
curl_bin="${DARWIN_REBUILD_WINDOWED_CURL_BIN:?not set}"
logger_bin="${DARWIN_REBUILD_WINDOWED_LOGGER_BIN:?not set}"
trusted_uid="${DARWIN_REBUILD_WINDOWED_TRUSTED_UID:?not set}"
flake_ref="${DARWIN_REBUILD_WINDOWED_FLAKE_REF:?not set}"

log() {
  "$logger_bin" -t darwin-rebuild-windowed "$*" || true
  echo "darwin-rebuild-windowed: $*" >&2
}

deny() {
  log "DENY: $*"
  exit 1
}

# trusted_path <path> <type>: the path exists with that find(1) type (f, d or s),
# is owned by the owner uid, and has neither group nor other write permission.
# find(1) gives the same answer on BSD and GNU.
trusted_path() {
  [ -n "$(find "$1" -maxdepth 0 -type "$2" -user "$owner_uid" ! -perm -020 ! -perm -002 -print 2>/dev/null)" ]
}

# json_ok <jq filter>: exits 0 when the filter holds for the lookup-self
# response. The response goes through a pipe, never a file, and is not logged.
json_ok() {
  printf '%s\n' "$response" | jq -e "$1" > /dev/null 2>&1
}

[ "$#" -eq 1 ] || deny "expected exactly one argument, the hostname (got $#)"
host="$1"
[[ "$host" =~ $hostname_re ]] || deny "hostname argument is not lowercase letters, digits and hyphens"

[ "$(id -u)" = "$trusted_uid" ] || deny "not running as the trusted uid"

trusted_path "$window_socket" s || deny "window socket is not a socket owned by the owner uid, or others can write it"
trusted_path "${window_socket%/*}" d || deny "window socket's directory is not owned by the owner uid, or others can write it"

# -q ignores any curl configuration file, so no option can come from one.
if ! response="$("$curl_bin" -q -sS -f --max-time 15 \
  --unix-socket "$window_socket" \
  http://localhost/v1/auth/token/lookup-self 2> /dev/null)"; then
  deny "window socket rejected lookup-self, or the proxy did not answer"
fi
json_ok '(.data.policies // []) | index("ai-admin") != null' || deny "window lacks the ai-admin policy"
json_ok '.data.meta.role_name == "ai-admin-session"' || deny "window is not the ai-admin-session role"
json_ok '(.data.ttl | type == "number") and .data.ttl > 0' || deny "window has no ttl above zero"
log "window accepted: ai-admin policy, ai-admin-session role, ttl above zero"

link_file="$cluster_dir/link-state"
peer_file="$cluster_dir/peer-state.json"
if [ ! -e "$link_file" ] || [ ! -e "$peer_file" ]; then
  log "cluster: state files absent, treated as not clustered"
else
  link="$(tr -d '[:space:]' < "$link_file")" || deny "cluster: link-state is unreadable"
  case "$link" in
    down)
      log "cluster: link-state down, treated as not clustered"
      ;;
    up)
      armed="$(jq -r '.armed' "$peer_file" 2> /dev/null)" || deny "cluster: peer-state.json is unreadable or not JSON"
      case "$armed" in
        true) deny "cluster: link-state up and peer armed, host is clustered" ;;
        false) log "cluster: link-state up, peer not armed, treated as not clustered" ;;
        *) deny "cluster: peer-state.json has no boolean armed field" ;;
      esac
      ;;
    *) deny "cluster: link-state holds an unexpected value" ;;
  esac
fi

log "run: darwin-rebuild switch --flake $flake_ref#$host --refresh"
rc=0
"$darwin_rebuild" switch --flake "$flake_ref#$host" --refresh || rc=$?
log "run: darwin-rebuild exited with $rc"
exit "$rc"
