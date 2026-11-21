---
name: bootstrap-stage
description: Specify and run an incremental bootstrap stage, making sure the predecessor compiles the successor.
---

# Bootstrap stage planning

Read `.claude/skills/bootstrap-incremental/SKILL.md`, `docs/roadmap/stages.md` and the bibliography before starting.

## Steps

1. Identify the exact predecessor seed and compiler, revision, host and accepted subset.
2. Run small probes of the required features; record the output without relying on unverified documentation.
3. Describe the previous subset and the new extension, with accepted/rejected examples.
4. Define inputs/outputs, the artifact contract, diagnostics, build errors and reproducible commands.
5. Propose the smallest vertical slice the predecessor can build.
6. Plan the sequential bootstrap, directory cleanup, tool provenance and artifact comparison.
7. State gates and limitations; DDC is an eligible plan only when an identified independent root exists.
8. Update roadmap/evidence/ADR for the stage, without presenting a plan as a conclusion.

## Output

Deliver the goal, subset, files, probes, command chain, gates, dependencies, risks, fallback and expected evidence. Do not widen the scope with advanced targets or runtime without a demonstrated dependency.
