# Credential masking for AI-CLI transcripts (standalone Edge GitOps config)
#
# One shared pipeline, the platform's native Mask function, attached as the
# post-processing pipeline of every transcript output in ./cribl.nix
# (cribl_claude, cribl_codex, cribl_agy, cribl_vscode). Post-processing runs
# after any source pipeline, so no input routes around it, and a new
# harness inherits it by shipping through one of those outputs.
#
# Why a worker-level pipeline and not a pack: this standalone Edge never
# loads pack-internal routing (see the pipelines comment in
# ./cribl-pipelines.nix), so a pack's pipeline would not run here.
#
# Patterns cover public, documented credential formats only. Masking does
# not replace rotation: a credential that reached a transcript was live.

{
  "pipelines/transcript_mask/conf.yml" = ''
    output: default
    description: Masks credential-shaped strings in AI-CLI transcripts before they leave the host.
    functions:
      - id: mask
        filter: "true"
        disabled: false
        conf:
          rules:
            # GitHub tokens (classic and the newer JWT-bodied App tokens) and
            # fine-grained PATs.
            - matchRegex: '/\b(gh[pousr]_[A-Za-z0-9_.\-]{30,}|github_pat_[A-Za-z0-9_]{40,})/g'
              replaceExpr: "'<redacted:github>'"
            # Secret-store tokens (service, batch and recovery prefixes).
            - matchRegex: '/\b(hv[sbr]|s|b|r)\.[A-Za-z0-9_\-]{24,}/g'
              replaceExpr: "'<redacted:bao>'"
            - matchRegex: '/\bdp\.(st|pt|ct|sa|scim|audit)\.[A-Za-z0-9_.\-]{20,}/g'
              replaceExpr: "'<redacted:doppler>'"
            - matchRegex: '/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g'
              replaceExpr: "'<redacted:private-key>'"
            - matchRegex: '/\beyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}/g'
              replaceExpr: "'<redacted:jwt>'"
            - matchRegex: '/\bxox[abposr]-[A-Za-z0-9\-]{10,}/g'
              replaceExpr: "'<redacted:slack>'"
            - matchRegex: '/\bsk-(ant-)?[A-Za-z0-9_\-]{20,}/g'
              replaceExpr: "'<redacted:api-key>'"
            - matchRegex: '/\b(AKIA|ASIA)[0-9A-Z]{16}\b/g'
              replaceExpr: "'<redacted:aws>'"
          # Every field, not only _raw: source pipelines parse transcript
          # JSON into fields, and those ship too.
          fields:
            - _raw
            - "*"
          depth: 5
  '';
}
