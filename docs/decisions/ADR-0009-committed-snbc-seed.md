# ADR-0009 — Committed SnBC seed for the first bootstrap stage

- **Status:** Proposed; slice 1 (SnBC seed run by `snl run-snbc`) implemented
- **Date:** 2026-11-21

## Context

The first bootstrap stage comes from the installed `snl`: `snl check` and
`snl build` compile `bootstrap/src/` into an executable that bundles SnBC with
the `snl` C VM (ADR-0005). That makes the whole `snl` frontend, lowering and
bundler part of the root of every later stage. The goal of the "own root"
milestone (phase P8 in [`stages.md`](../roadmap/stages.md)) is a first stage
that does not depend on the installed `snl` compiler.

Probes recorded in the evidence log (2026-11-21, `x86_64-unknown-linux-gnu`):

- the SnBC image produced by the compiler's fixed point, run by
  `snl run-snbc` with `SNL_OUTPUT`, compiles the current sources into the same
  image;
- an image produced five commits earlier (different bytes) compiled the
  current sources into the current fixed-point image in one generation, so a
  seed does not need to change with every source change;
- `snl run-snbc` v0.3.0 passes no program arguments, so a seed run this way
  can only use the self-compilation mode, not the full CLI;
- the native backend emits the compiler's aarch64-apple-darwin assembly
  deterministically on a Linux host (4350137 bytes), but it can be assembled
  and run only on the qualified host.

## Options

1. **SnBC seed run by `snl run-snbc`.** Commit the fixed-point image (142693
   bytes). Removes `snl check`/`snl build` from the first stage; keeps the
   `snl` C VM as executor. Portable to every host with an `snl` release.
2. **Native assembly seed per target.** Commit the compiler's generated
   assembly for a qualified target and assemble/link it with the host
   `as`/`ld`. Removes `snl` from the chain on that target and yields a full
   CLI. Needs a qualified target per host (only `aarch64-apple-darwin` today;
   Linux waits for T1 in ADR-0008) and a policy for a large generated file.
3. **Hand-written minimal assembly seed or separate native executor.**
   Rejected: it would make assembly a general implementation language and
   duplicate compiler logic (ADR-0003).

## Decision

Adopt option 1 as slice 1 and option 2 as slice 2, in that order.

Slice 1:

- `bootstrap/seed/compiler.snbc` is the committed seed, with its SHA-256 in
  `bootstrap/seed/compiler.snbc.sha256` and provenance in
  `bootstrap/seed/README.md`. It is a generated artifact, never hand-edited.
- `make bootstrap-seed-stage` checks the seed hash, runs the seed with
  `snl run-snbc` to produce `seed-stage1.snbc`, and runs that image to produce
  `seed-stage2.snbc`. It does not call `snl check` or `snl build`.
- `make bootstrap-seed-fixed-point` requires `seed-stage1 == seed-stage2`
  (fixed point of the seed chain) and `seed-stage1 == stage1` from the
  `snl build` path (differential between the two first stages).
- `make bootstrap-seed-refresh` replaces the seed with the fixed-point image
  of the `snl build` path. A refresh is required only when the seed can no
  longer compile the sources (ADR-0001 growth rule) and must be recorded in
  the evidence log.

Slice 2 (separate change, gated on the qualified host): commit the
aarch64-apple-darwin compiler assembly as a native seed and run the N3 chain
from it without `snl`.

## Consequences

- The first stage of the seed chain no longer depends on `snl check` or
  `snl build`. It still depends on the `snl run-snbc` C VM, so this is not yet
  an own root and not DDC (ADR-0002).
- The `snova-bootstrap` CLI used by the smoke, diagnostics, executor, native
  and library gates still comes from `snl build`, because `snl run-snbc`
  passes no arguments.
- The seed is a binary generated file in the repository. Its trust rests on
  the recorded hash, the reproducible refresh command and the differential
  against the `snl build` path.
- Cross-host equality of the seed (Linux x86-64 and aarch64-apple-darwin
  producing the same bytes) is expected because SnBC is host-independent, but
  it is unproven until both hosts record the same hash.

## Reopen when

Slice 2 is qualified, the SnBC executor runs natively, `snl run-snbc` gains
argument passing, or a seed refresh is needed more often than source changes
that add language features.
