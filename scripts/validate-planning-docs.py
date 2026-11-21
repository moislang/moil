#!/usr/bin/env python3
"""Validate planning structure and local Markdown links using only Python stdlib."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "README.md",
    "docs/architecture/overview.md",
    "docs/roadmap/stages.md",
    "docs/roadmap/evidence.md",
    "docs/decisions/ADR-0001-incremental-subsets.md",
    "docs/decisions/ADR-0002-evidence-and-fixed-point.md",
    "docs/decisions/ADR-0003-language-boundaries.md",
    "docs/diagrams/bootstrap.mmd",
    "docs/diagrams/compiler-pipeline.mmd",
    ".claude/rules/architecture.md",
    ".claude/rules/documentation.md",
    ".claude/skills/bootstrap-incremental/SKILL.md",
    ".claude/skills/self-hosting-research/SKILL.md",
    ".claude/skills/bootstrap-stage/SKILL.md",
    ".claude/skills/compiler-frontend/SKILL.md",
    ".claude/skills/semantic-ir/SKILL.md",
    ".claude/skills/backend-runtime/SKILL.md",
    ".claude/skills/conformance-determinism/SKILL.md",
    ".claude/agents/bootstrap-architect.md",
    ".claude/agents/frontend-engineer.md",
    ".claude/agents/semantic-ir-engineer.md",
    ".claude/agents/backend-runtime-engineer.md",
    ".claude/agents/conformance-reviewer.md",
    ".claude/agents/compiler-researcher.md",
    "docs/research/compiler-literature.md",
)
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def main() -> int:
    errors: list[str] = []
    for item in REQUIRED:
        if not (ROOT / item).is_file():
            errors.append(f"missing required file: {item}")

    for markdown in ROOT.rglob("*.md"):
        if ".git" in markdown.parts:
            continue
        content = markdown.read_text(encoding="utf-8")
        for target in LINK.findall(content):
            target = target.split("#", 1)[0]
            if not target or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            resolved = (markdown.parent / target).resolve()
            if not resolved.exists():
                errors.append(f"{markdown.relative_to(ROOT)}: broken link: {target}")

    if errors:
        print("Planning documentation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Planning documentation structure and local links are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
