# Development workflow

This workflow organizes the work before each feature and defines how to keep the plan in sync with the implementation.

## Before implementing

1. Read `README.md`, the rules in `.claude/rules/` and the relevant skill.
2. Confirm the current repository root before editing files.
3. Read the applicable ADR and phase; check `docs/roadmap/evidence.md`.
4. For a dependency on the host compiler, run an isolated probe and record version, command and result.
5. Specify subset, syntax, semantics, errors, positive/negative fixtures and the completion criterion.
6. Plan a small vertical slice that the previous compiler can build.

## During implementation

- Keep one declaration per file when that improves locality and review; avoid monoliths and use explicit types/returns.
- Use `PascalCase` for class, struct, interface, enum and other type names. Use
  `camelCase` for functions, methods and variables. Use `PascalCase` for source
  file names, matching their primary declaration or responsibility.
- Compiler/runtime code goes in `.moi`/`.sns`; assembly only at the approved boundary.
- Do not advance subset features without support in the predecessor compiler.
- Write documentation and code comments in English.
- Record observed limitations and update diagrams/ADRs only when the architecture changes.

## Closing a milestone

1. Run only the checks defined for the milestone and report commands/results.
2. Compare behavior with the reference when applicable.
3. Update `evidence.md`, the subset matrix and the roadmap status.
4. Confirm that changes are limited to the intended repository.
5. Distinguish build, test, native execution, cross-compilation, reproduction and DDC.

## Pull requests

Future PRs must state the phase/milestone, affected subset, risks, evidence, limitations and rollback plan. Architecture changes require an updated ADR. Language changes require accepted and rejected examples. A failure on one target cannot be hidden by success on another.
