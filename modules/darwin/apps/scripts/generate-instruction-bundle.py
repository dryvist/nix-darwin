#!/usr/bin/env python3
"""generate-instruction-bundle.py

Generates a concatenated instruction bundle for non-Claude harnesses (OpenCode).
Replaces Claude-only @import / @file syntax by recursively concatenating referenced files
so that OpenCode receives the complete instruction context in a single document.
Includes root confinement to prevent path traversal.
"""

import os
import re
import sys
from pathlib import Path

IMPORT_PATTERN = re.compile(r"^\s*@(import|file)\s+([^\s]+)\s*$", re.MULTILINE)

def is_within_roots(path: Path, allowed_roots: list[Path]) -> bool:
    """Verifies that path is contained within at least one allowed root directory."""
    resolved = path.resolve()
    for root in allowed_roots:
        try:
            resolved.relative_to(root)
            return True
        except ValueError:
            continue
    return False

def inline_imports(content: str, base_dir: Path, visited: set, allowed_roots: list[Path]) -> str:
    """Recursively inlines @import and @file directives with path confinement."""
    def replacer(match):
        rel_path = match.group(2)
        target = (base_dir / rel_path).resolve()

        if not target.is_file():
            # If not found relative to base_dir, check home directory ~/.agents
            home_target = (Path.home() / ".agents" / rel_path.lstrip("~").lstrip("/")).resolve()
            if home_target.is_file():
                target = home_target
            else:
                print(f"[instruction-bundle] Warning: missing import target '{rel_path}'", file=sys.stderr)
                return f"<!-- Missing import target: {rel_path} -->"

        # Security check: confine imports to allowed root directories
        if not is_within_roots(target, allowed_roots):
            print(f"[instruction-bundle] Security error: import target '{target}' outside allowed roots", file=sys.stderr)
            return f"<!-- Security error: import target outside allowed roots: {rel_path} -->"

        if target in visited:
            return f"<!-- Circular reference skipped: {rel_path} -->"

        visited.add(target)
        try:
            target_content = target.read_text(encoding="utf-8")
            return (
                f"\n<!-- BEGIN INLINED: {rel_path} -->\n"
                + inline_imports(target_content, target.parent, visited, allowed_roots)
                + f"\n<!-- END INLINED: {rel_path} -->\n"
            )
        except Exception as e:
            print(f"[instruction-bundle] Error reading {rel_path}: {e}", file=sys.stderr)
            return f"<!-- Error reading {rel_path}: {e} -->"

    return IMPORT_PATTERN.sub(replacer, content)

def main():
    if len(sys.argv) < 3:
        print(f"usage: {sys.argv[0]} <source-agents-md> <output-bundle-md> [additional-rules-dir]", file=sys.stderr)
        sys.exit(1)

    src_file = Path(sys.argv[1]).expanduser().resolve()
    out_file = Path(sys.argv[2]).expanduser().resolve()
    rules_dir = Path(sys.argv[3]).expanduser().resolve() if len(sys.argv) > 3 else None

    if not src_file.is_file():
        print(f"[instruction-bundle] Source file {src_file} does not exist", file=sys.stderr)
        sys.exit(0)

    # Allowed roots for import resolution: source file directory, ~/.agents, ~/.config
    allowed_roots = [
        src_file.parent,
        (Path.home() / ".agents").resolve(),
        (Path.home() / ".config").resolve(),
    ]
    if rules_dir and rules_dir.is_dir():
        allowed_roots.append(rules_dir)

    visited = {src_file}
    content = src_file.read_text(encoding="utf-8")
    bundled = inline_imports(content, src_file.parent, visited, allowed_roots)

    # Append any core rules from rules_dir if specified
    if rules_dir and rules_dir.is_dir():
        bundled += "\n\n# Core Rules\n"
        for rule_path in sorted(rules_dir.glob("*.md")):
            if rule_path.is_file():
                bundled += f"\n\n## {rule_path.stem}\n\n"
                bundled += rule_path.read_text(encoding="utf-8")

    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(bundled, encoding="utf-8")
    print(f"[instruction-bundle] Generated {out_file} ({len(bundled)} bytes)")

if __name__ == "__main__":
    main()
