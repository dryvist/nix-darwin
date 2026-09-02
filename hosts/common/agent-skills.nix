{
  programs.agentSkills = {
    # Codex scans both native roots. Select ~/.agents/skills for the shared
    # catalog; never also link ~/.codex/skills, which scans every skill twice.
    root = "agents";

    # Deploy the whole catalog, which is this option's own default.
    #
    # This root is read by Codex, Cursor, OpenCode, qwen and Antigravity, and
    # NOT by Claude Code — Claude reads ~/.claude/skills, its enabled plugins,
    # and <repo>/.claude/skills. So the size of this tree does not enter a
    # Claude session's context at all, and restricting it bought no Claude
    # budget while removing skills from every other harness.
    #
    # It previously carried only the `core` group, on the assumption that a
    # repository declares the rest in its AGENTS.md `skill-groups` frontmatter
    # and gets them linked on direnv load. Measured against real usage in the
    # local session transcripts, that assumption did not hold: 121 skills with
    # 164,619 recorded invocations were absent from this tree, including
    # finalize-pr (18,920), promote-release (16,124), ship (11,834) and the
    # ponytail review family (~30,000) — skills used in every repository rather
    # than one domain, which no per-repo declaration reliably covers.
    #
    # Per-repository scoping still applies where it earns its keep: the repo
    # linker writes <repo>/.claude/skills, which Claude DOES read and which is
    # therefore the tree worth gating.
    activeGroups = null;
  };
}
