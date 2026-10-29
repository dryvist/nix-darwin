# Cribl Edge worker-level pipelines (standalone GitOps config)
#
# Split out of ./cribl.nix for the repo file-size gate; merged straight back
# into `programs.cribl-edge.standalone.configFiles` there. The pipelines of the
# released packs are installed by packPipelineFiles in ./cribl.nix; what remains
# here is the AI-CLI pipelines.

{ codexPack, geminiPack }:

{
  # AI-CLI transcript pipelines, taken VERBATIM from the released pack
  # derivations (see the let block at the top) and installed as
  # worker-level pipelines. Why not run them inside the packs: on this
  # standalone Edge the pack-internal routing layer never loads — the
  # live API serves every pack a fallback `filter:true -> pipeline:main`
  # route (a pipeline none of the packs define), so events QuickConnected
  # into `pack:<id>` pass through UNPROCESSED (verified in Splunk:
  # port-stamped sourcetype, no llm.* fields). Worker-level pipelines +
  # QuickConnect are the proven path (the pack pipelines in ./cribl.nix).
  "pipelines/codex_sessions/conf.yml" =
    builtins.readFile "${codexPack}/default/pipelines/codex_sessions/conf.yml";
  "pipelines/claude_sessions/conf.yml" = builtins.readFile ./cribl-claude-sessions.conf.yml;
  "pipelines/codex_history/conf.yml" =
    builtins.readFile "${codexPack}/default/pipelines/codex_history/conf.yml";
  "pipelines/llm_normalize/conf.yml" =
    builtins.readFile "${geminiPack}/default/pipelines/llm_normalize/conf.yml";
}
