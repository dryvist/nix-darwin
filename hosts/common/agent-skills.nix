{
  programs.agentSkills = {
    # Codex scans both native roots. Select ~/.agents/skills for the shared
    # catalog; never also link ~/.codex/skills, which scans every skill twice.
    root = "agents";
    # The workstation carries only the core group; a repository declares the
    # rest in its AGENTS.md frontmatter (skill-groups) and gets them linked on
    # direnv load.
    activeGroups = [ "core" ];
  };
}
