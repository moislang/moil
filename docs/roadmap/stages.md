# Development roadmap

The roadmap is a sequence of gates. The next phase does not start until the minimum evidence for the previous one is recorded. Dates and estimates stay out of this plan until there are real measurements.

| Phase | Deliverable | Gate to advance |
|---|---|---|
| P0 — Discovery | Inventory of the installed `moil`: version, host, file/process interfaces, syntax and seed limits. Small, reproducible probes. | Every capability the seed uses has a probe and a result; limitations and version are recorded. No implicit dependency on `moil run`. |
| P1 — Contracts | Specification of the first subset, input/output formats, diagnostics, initial layout and a baseline of the reference compiler. | Accepted and rejected cases defined; automatable equivalence criteria. |
| P2 — Hello vertical | A minimal seed in Moislang (confirmed subset) that generates a simple host program; minimal assembly only if indispensable. | Clean build, execution, exit status and stdout verified; the seed can be rebuilt with the documented procedure. |
| P3 — First compiler | Lexer, minimal parser, intermediate representation and a backend for one target; compiles examples and a subset of itself. | Positive/negative differentials, errors with positions, defined semantics for each implemented feature. |
| P4 — Incremental growth | Extend the subset in small milestones: data/collections, functions and calls, types, modules and runtime according to real dependencies. | For each extension: tool probe, spec, fixtures, differential and a build by the previous compiler. |
| P5 — Bootstrap | The previous compiler generates the new compiler; repeated builds with fixed inputs/toolchain. | Recorded chain, compared artifacts, hashes and explained differences. |
| P6 — Compatibility | Gradually expand CLI, projects, builtins, diagnostics and the reference corpus. | Updated compatibility matrix; unsupported behavior explicitly listed. |
| P7 — Additional platforms | Port the backend and ABI after the host is stable. | Each target has assemble/link/run when a toolchain is available; limitations separate compilation from execution. |
| P8 — DDC and maintenance | Independent root, chain of trust and seed update flow. | Explicit root of trust; independent comparison documented. If that is not possible, DDC is marked as unproven. |

## Current state

The Mois seed is integrated in `bootstrap/src/`. There is local evidence of:
check; build by `moil build` (SnBC bundled with the C VM, not machine code);
execution of a generated program; positive/negative diagnostics; compilation
of the source by the seed; equality of two SnBC images; and execution of the
compiler image by the SnBC executor written in Mois, reproducing the same
image.

The native backend (ADR-0005) has slices N1 (numeric), N2 (Mois runtime
with ownership-based memory release, ADR-0006), and N3 (native compiler
fixed point) implemented for `aarch64-apple-darwin`. The first stage still
uses `moil build`; assembly and linking still use the host `as`/`ld`. This is
not a portable release and does not replace `moisc`. The multi-target
sequence is recorded in ADR-0008; Linux/x86-64 is its first expansion target.

Own root (P8), proposed in ADR-0009: slice 1 commits the compiler's SnBC
fixed-point image as a seed. `make bootstrap-seed-fixed-point` runs it with
`moil run-snbc`, without `moil check` or `moil build`, and requires the same
stage-1 image as the `moil build` path. The seed chain still runs on the `moil`
C VM, so this is not an own root or DDC yet. Slice 2 (a native assembly seed
for `aarch64-apple-darwin`) is pending.

This closes a restricted initial cycle; it does not close compatibility or
replace `moisc`. The expansion sequence and the limits are in
[`subset.md`](subset.md), and the reproducible commands are in the `Makefile`.

## Growth rule

The subset of compiler `N+1` must be contained in the subset that compiler `N` can compile. A new feature is delivered in this order: probe → specification → fixture → minimal implementation → differential → build of the next stage. Avoid jumping to dozens of features before closing a full cycle.

## Outside the first milestone

Multi-target, advanced collectors, exceptions with unwinding, concurrency, full CLI compatibility and DDC are not requirements of the first hello vertical. Reintroducing them requires its own motivation and gate. Deterministic memory release is not optional: the native runtime frees memory through ownership (ADR-0006) without a tracing collector.

## Execution log

Each phase must update `docs/roadmap/evidence.md` with commit/revision, host, compiler version, command, result, artifacts and limitations. Do not record intent as completed evidence.
