# Skill Namespace Resolution Rules

## Problem

Claude was repeatedly calling skills with incorrect namespaces (e.g.,
`superpowers:code-reviewer` when the correct namespace was
`pr-review-toolkit:code-reviewer`). This happened across multiple
skills and sessions.

Root cause: Claude made assumptions about namespacing instead of reading exact strings from error output.

## Solution: Authoritative Namespace Lists

**When invoking ANY skill or agent, use the EXACT string from the system's error output or available list.**

### Format Rules

#### Skill Tool Invocation

```yaml
Skill tool parameter: "namespace:skill-name"

Examples (EXACT):
  - pr-review-toolkit:code-reviewer
  - superpowers:finishing-a-development-branch
  - backend-development:backend-architect
```

#### Task Tool Agent Invocation

```yaml
subagent_type parameter: "namespace:skill-name"

Examples (EXACT):
  - pr-review-toolkit:code-reviewer
  - backend-development:backend-architect
  - Explore (no namespace - built-in)
```

### When You Get "Unknown Skill" or "Agent Type Not Found" Error

#### Step 1: Read the Error Completely

The error message ALWAYS includes a list of available agents/skills in this format:

```text
Available agents: Agent1, Agent2, namespace:skill-1, namespace:skill-2, ...
```

#### Step 2: Find Your Target

Locate your desired skill/agent name in the list.

#### Step 3: Copy EXACT String

Copy the EXACT string from the list - do NOT:

- Abbreviate or shorten it
- Change the namespace
- Guess a pattern
- Trust assumptions over what the system shows

#### Example Correct Behavior

```text
Error output shows:
"... Available agents: ... pr-review-toolkit:code-reviewer, superpowers:finishing-a-development-branch, ..."

Action: Copy "pr-review-toolkit:code-reviewer" exactly
```

#### Example WRONG Behavior (NEVER DO THIS)

```text
Error shows: pr-review-toolkit:code-reviewer
Claude thought: "It's a review tool, superpowers probably has review skills too"
Claude tried: superpowers:code-reviewer
Result: WRONG - Error again
```

## Common Namespace Confusion Patterns

| Situation | ❌ Wrong | ✓ Correct | Why |
| --- | --- | --- | --- |
| Error shows `pr-review-toolkit:code-reviewer` | `superpowers:code-reviewer` | Copy exact string | Trust system output |
| Unsure of full namespace | Use only the skill name without namespace | Use `namespace:skill-name` | Exact format required |
| Want to guess based on task type | Assume a namespace | Copy from error list | Error lists are authoritative |
| Multiple similar namespaces | Pick what seems right | Ask user or copy exact | Never guess |

## Prevention

### For Claude Instances

1. **Assumption Detection**: If you think you might be guessing a namespace, STOP
2. **Error Reading**: Always read error messages for "Available agents/skills:" lists
3. **Copy-Paste**: Take exact strings directly from error output
4. **Verify**: Before invoking, confirm the string matches exactly

### For Repository Maintainers

- Keep namespace documentation up-to-date
- Error messages must clearly show available options
- Validate that available options in errors match actual registered skills

## Files Using This Rule

- `AGENTS.md` - Agent invocation instructions
- `CLAUDE.md` - Project-specific instructions
- This file - Rule documentation

## Related

- See AGENTS.md and CLAUDE.md "Skill and Agent Invocation Rules" for user instructions in this repo
- See pr-review-toolkit, superpowers, and other skill namespaces for examples
