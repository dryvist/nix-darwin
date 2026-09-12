# The rendered Caddyfile for programs.llm-gate.
#
# The whole Caddyfile is a plain, secret-free nix store file: every sensitive
# value is an {env.VAR} placeholder resolved by Caddy at parse time from the
# openbao-run-injected environment. Safe to be world-readable — it contains no
# secrets, only the (already public) hostnames.
#
# The site fragments are rendered by the caller (./llm-gate.nix) and passed in,
# so this file holds the document and nothing that decides its content.

{
  pkgs,
  cfg,
  apiSiteAddresses,
  bindDirective,
  tlsDirective,
  requestBodyDirective,
  clusterSite,
}:

pkgs.writeText "llm-gate.Caddyfile" ''
  {
    admin off
    auto_https disable_redirects
  }

  ${apiSiteAddresses} {
    ${bindDirective}
    ${tlsDirective}
    ${requestBodyDirective}
    # JSON access log — the only place API-consumer traffic is visible (the
    # model server on loopback only ever sees the proxy). Written into the
    # gate's log dir (0755, outside the 0700 dataDir so a non-root Cribl
    # Edge can traverse it; ~/Library/Logs per macOS convention) and tailed
    # by the Cribl Edge in_gate_access file input (hosts/common). Caddy's
    # default rolling applies (100 MiB rolls, keep 10, 90 days), so no
    # newsyslog entry is needed.
    log {
      output file ${cfg.logDir}/access.json
      format json
    }
    @unauthorized not header Authorization "Bearer {env.LLM_LARGE_BEARER_TOKEN}"
    respond @unauthorized 401
    reverse_proxy 127.0.0.1:${toString cfg.apiUpstreamPort}
  }

  ${clusterSite}
''
