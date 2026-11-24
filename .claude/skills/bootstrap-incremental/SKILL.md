---
name: bootstrap-incremental
description: Plan or implement a stage of the self-hosted compiler without creating a gap between the seed and the language used by the next stage.
---

# Incremental Moislang bootstrap

## When to use

Use when planning `moil` probes, choosing a subset, designing the seed, implementing a compiler feature, adding a bootstrap step or evaluating self-hosting evidence.

Also use the specialized skills for each phase: `bootstrap-stage`, `compiler-frontend`, `semantic-ir`, `backend-runtime`, `conformance-determinism` and `self-hosting-research`.

## Constraints

- Work only in the current checkout; `../moisc` is a read-only reference.
- Prefer `.snl`/`.sns`. Use assembly only at justified boundaries, and never C as a parallel implementation without an explicit decision.
- Do not assume that the installed version, syntax or runtime matches historical documentation. Record the version before the probes.
- Do not call a build DDC if the second root is not independent.
- Compiler code must build with both the seed and the current root; follow the object-model rules of ADR-0007.

## Procedure

1. **Identify the stage.** Read `docs/roadmap/stages.md`, `docs/roadmap/evidence.md`, the ADRs and the current subset matrix.
2. **Measure the required capability.** Run a minimal, isolated probe for each `moil` feature the next stage depends on. Record command, version and output.
3. **Define the subset.** List accepted/rejected constructs, semantics, limits and fixtures. Make sure the sources of stage N+1 only use features that N can compile.
4. **Choose the smallest vertical path.** Seed → executable artifact → functional test. Postpone features without a direct dependency.
5. **Define contracts.** Types, ownership, errors/diagnostics, spans, IR/artifact formats, ABI and determinism.
6. **Organize the modules.** Use `PascalCase` `.snl` files aligned with their primary type or responsibility, PascalCase types, explicit packages/imports between modules, small public APIs and files under 400 lines when possible.
7. **Implement in slices.** Each slice includes positive and negative behavior and can be compiled by the existing predecessor.
8. **Compare with the reference.** When applicable, run a differential corpus and group divergences by phase; do not accept "it compiles" alone.
9. **Record evidence.** Update `evidence.md` with environment, commands, results, hashes and limitations.
10. **Make the correct claim.** State separately whether bootstrap, self-compilation, fixed point, reproducibility or DDC was demonstrated.

## Review checklist

- [ ] Does the previous stage fully build the next one?
- [ ] Do all host capabilities have current probes?
- [ ] Are there accepted and rejected cases, and diagnostics with positions?
- [ ] Does any new assembly have a contract, without duplicating high-level logic?
- [ ] Do files and APIs keep the size limit and PascalCase file/type naming convention?
- [ ] Are output and ordering deterministic?
- [ ] Does the evidence distinguish execution, cross-compilation, fixed point and DDC?
- [ ] Was `../moisc` left untouched?

## Expected output when planning

Deliver: stage and goal; predecessor/successor subset; probes; planned files; contracts; acceptance criteria; risks and dependencies; required evidence. Do not present future items as available features.
