# Feature specifications

A specification is the second step of the growth rule in
[`stages.md`](../roadmap/stages.md): probe → **specification** → fixture →
minimal implementation → differential → build of the next stage. It fixes
the goal, the accepted and rejected cases, the diagnostics, the slices and the
gates before code is written. A specification is a planning document: it does
not claim that anything is implemented. Observed facts go to
[`evidence.md`](../roadmap/evidence.md); architecture decisions go to an ADR.

Each specification has an explicit status (`Proposed`, `Accepted`,
`Implemented`, `Superseded`) and lists its open questions.

- [SPEC-0001: instance-based library API](SPEC-0001-library-instance-api.md)
- [SPEC-0002: frontend borrow checker and weak references](SPEC-0002-borrow-checker-weak-references.md)
