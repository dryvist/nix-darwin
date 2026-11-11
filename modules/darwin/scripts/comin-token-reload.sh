# shellcheck shell=bash
# Restart comin after its access-token file changes, so its next fetch uses the new token.
#
# comin reads `access_token_path` once, when it loads its configuration at start, so a token file
# rewritten later is not seen until comin restarts. launchd runs this job when the token directory changes
# (WatchPaths), so comin restarts at most once per token rewrite. While comin reports that it is
# fetching, evaluating, building or deploying, the restart is skipped and logged, and the next rewrite
# of the token checks again.
#
# Environment:
#   COMIN_LABEL  launchd label of the comin daemon (injected by the module)
#   LAUNCHCTL    launchctl to call (test seam; defaults to /bin/launchctl)

label="${COMIN_LABEL:?COMIN_LABEL not set}"
launchctl_bin="${LAUNCHCTL:-/bin/launchctl}"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# The first activity comin reports, or empty when it is idle or cannot be read.
busy=""
if status="$(comin status --json 2> /dev/null)"; then
  busy="$(jq -r '
    [ (if .fetcher.is_fetching == true then "fetching" else empty end),
      (if .builder.is_evaluating == true then "evaluating" else empty end),
      (if .builder.is_building == true then "building" else empty end),
      (if .deployer.is_deploying == true then "deploying" else empty end) ] | first // ""
  ' <<< "$status" 2> /dev/null || true)"
fi

if [ -n "$busy" ]; then
  echo "$(ts) comin-token-reload: token directory changed; restart deferred because comin is $busy."
  exit 0
fi

echo "$(ts) comin-token-reload: token directory changed; restarting $label."
"$launchctl_bin" kickstart -k "system/$label"
