# shellcheck shell=bash
# Restart comin after its access-token file changes, so its next fetch uses the new token.
#
# comin reads `access_token_path` once, when it loads its configuration at start, so a token file
# rewritten later is not seen until comin restarts. launchd runs this job when the token directory changes
# (WatchPaths). A deployment in progress is never interrupted: the restart is skipped and logged, and
# the next rewrite of the token checks again.
#
# Environment:
#   COMIN_LABEL  launchd label of the comin daemon (injected by the module)
#   LAUNCHCTL    launchctl to call (test seam; defaults to /bin/launchctl)

label="${COMIN_LABEL:?COMIN_LABEL not set}"
launchctl_bin="${LAUNCHCTL:-/bin/launchctl}"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

deploying=false
if status="$(comin status --json 2> /dev/null)"; then
  deploying="$(jq -r '.deployer.is_deploying // false' <<< "$status" 2> /dev/null || echo unknown)"
fi

if [ "$deploying" = true ]; then
  echo "$(ts) comin-token-reload: token directory changed; restart deferred because a deployment is in progress."
  exit 0
fi

echo "$(ts) comin-token-reload: token directory changed; restarting $label."
"$launchctl_bin" kickstart -k "system/$label"
