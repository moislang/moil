# SPEC-0002 — Frontend borrow checker and weak references

- **Status:** Proposed; diagnostic namespace and placement decided
- **Date:** 2026-11-21
- **Phase:** P4, incremental growth (semantics), then N3 performance
- **Related:** [ADR-0006](../decisions/ADR-0006-native-runtime.md) (ownership
  runtime; "Consequences" and "Reopen when"),
  [ADR-0007](../decisions/ADR-0007-object-model.md),
  [`subset.md`](../roadmap/subset.md) (Semantics and Runtime rows)

## Goal

1. Reject ownership errors in the seed's frontend, with stable codes and
   spans, the way `moil check` already rejects them: use after move and move
   out of a field or array element.
2. Give the native backend static ownership facts so it can drop dynamic
   counts and use faster copies and release for N3 (ADR-0006).
3. Define the gate that weak references must pass before they enter the
   subset. They are not specified here (see "Weak references").

## Non-goals

- Lifetimes in signatures, `&mut`, raw pointers, `unsafe`, `defer`, tasks
  (`MOISL0244`, `MOISL0247`) and nullable references.
- A tracing or cycle collector. Strong cycles stay rejected at run time by
  the native runtime (`nativeCycle`, status 70).
- Changing what the emitters or the backend produce in slices B1–B2: those
  slices only add diagnostics, in a pass of their own.

## Current state

- Ownership is analysed only in the backend, over SnBC stack slots
  (`bootstrap/src/NativeOwnership.snl`, runtime type `Ownership` in
  `bootstrap/runtime/Ownership.snl`): each local, temporary, field and
  element holds a count; `LOAD_LOCAL` produces an uncounted borrow until it
  escapes (ADR-0006, decision 6).
- Type checks live inside the emitters (`EmitExpr.snl`, `Emit.snl`;
  `SNV4001`–`SNV4003` printed by `Compiler.snl`). There is no separate
  semantic pass on master. Irineu's open PRs add `SNV4004` (non-exhaustive
  `match`, [snl#4](https://github.com/moislang/moil/pull/4), in its own
  `MatchCheck.snl` called from lowering), `SNV4005` (assignment to an
  immutable binding, [snl#7](https://github.com/moislang/moil/pull/7)) and
  `SNV4006` (argument count, [snl#9](https://github.com/moislang/moil/pull/9)).
- The seed's reaction to a move out of an array element is understood
  ([snl#8](https://github.com/moislang/moil/pull/8), gap inventory): for
  `let cell = cells[0]` the reference reports `MOISL0251` at the index
  expression, while the seed fails one statement later with `SNV3001`,
  because the moved local has an unknown type. `SNV5002` closes that gap.
- Probes (see `evidence.md`, "probes for the library and borrow-checker
  specifications"), comparing `moil check` v0.3.0 with the seed:

  | Program | `moil check` | Seed |
  |---|---|---|
  | `var b = a` (array), then `a.len()` | `MOISL0240` | accepts; executors print `3` |
  | move inside an `if`, use after it | `MOISL0240` | accepts |
  | `var p = o` (object), then `o.value` | `MOISL0240` | accepts |
  | `var b = a`, then `a = [4]` and `a.len()` | `MOISL0240` (twice) | accepts |
  | `var taken = holder.items` (field) | `MOISL0251` | accepts |
  | `take(a)` (array argument), then `a.len()` | accepts | accepts |
  | `var t = s` (string), then `s` | accepts | accepts |
  | `var y = x` (int), then `x` | accepts | accepts |
  | `total(&a)` with parameter `&int[]` | accepts | `SNV2001` at the `&` |

- `bootstrap-check` runs `moil check --project bootstrap/src`, so the compiler
  sources already obey the root's move rules, and they contain no `&`
  expression. A seed check that is a subset of those rules does not reject
  the compiler itself.

## Decisions

Recorded on 2026-11-21, decided by Inhegas (Engineering Lead):

1. **Diagnostic namespace.** The seed keeps its own codes, one block per
   phase. In `bootstrap/src/Compiler.snl` today: `SNV1xxx` lexer
   (`SNV1001`), `SNV2xxx` parser (`SNV2001`), `SNV3xxx` lowering
   (`SNV3001`), `SNV4xxx` types (`SNV4001`–`SNV4003` on master;
   `SNV4004`–`SNV4006` are taken by snl#4, #7 and #9), and `SNW0001` for the
   comparison warning. The borrow checker gets a new block, `SNV5xxx`, so
   its codes cannot collide with the semantic ones.
   Reference codes (`MOISL02xx`) never appear in seed output, so the prefix
   always says which compiler produced an error.
2. **Placement.** The checker is a separate pass between analysis and
   emission, in its own module `bootstrap/src/BorrowCheck.snl`. The emitters
   (`Emit.snl`, `EmitExpr.snl`, `EmitStmt.snl`) do not change, which is what
   guarantees the "identical SnBC images" criterion below.

## Proposed surface

Two new errors, each with the binding's byte span, in the format of
`SNV4002`:

| Code | Message |
|---|---|
| `SNV5001` | `use of a moved value at line L, span S..E` |
| `SNV5002` | `cannot move a value out of a field or array element at line L, span S..E` |

The single source for the correspondence between seed codes and
`moil check` codes is `docs/roadmap/diagnostics.md`, created by
[snl#4](https://github.com/moislang/moil/pull/4) and not yet on master. Its
header already reserves `SNV5xxx` for this checker. B1 and B2 each add their
row to that table when they land; this specification keeps no table of its
own. Mirrored excerpt, for reading only (the table in `diagnostics.md`
wins on any difference):

| Seed | `moil check` v0.3.0 | Meaning |
|---|---|---|
| `SNV5001` | `MOISL0240` | use of a moved value |
| `SNV5002` | `MOISL0251` | move out of a field or array element |

No new syntax in B1–B2.

## Semantics (B1–B2)

- **Movable values:** arrays and objects. Ints, bools and strings are
  copied (probes above).
- **Move:** binding or assigning a local of movable type to another local
  (`let`/`var` initializer or assignment). A call argument is not a move:
  `moil check` accepts a use after `take(a)` (probe above).
- **State:** each local is `live`, `moved` or `maybe moved`. A read of a
  `moved` or `maybe moved` local fails with `SNV5001`. At the join of
  `if`/`else` and after a `while` body, a local moved on any path is
  `maybe moved`.
- **Reassignment:** closed (open question 1, Villa, 2026-11-21). The seed
  follows `moil check` v0.3.0: after a move, assigning to that `var` local
  is itself a use of a moved value (`MOISL0240` at the left-hand name,
  `SNV5001` in the seed), even when the local is not read afterwards.
  A later use is a second error. Yuri may revisit.
- **Field and element moves:** binding a field or an array element of
  movable type to a local fails with `SNV5002`. Passing it as a call
  argument stays allowed (SPEC-0001, rule 4).
  Assigning a local into a field or array element does not move from that
  local; only assignment to another local transfers its move state.

## Slices

- **B0 — probes.** Done for the table above; extend to `return`, `while`,
  method receivers and struct fields of struct type before B1 starts.
- **B1 — use after move** (`SNV5001`): create `BorrowCheck.snl`, add it to
  `ownSource()` in `SourceJoin.snl`, and call it from the driver after
  parsing and before emission; straight-line code first, then `if`/`while`
  joins. Add the `SNV5001` row to `diagnostics.md`.
- **B2 — move out of a field or element** (`SNV5002`), in the same pass;
  add its row to `diagnostics.md` and turn the snl#8 inventory entry for
  `let cell = cells[0]` into a closed gap.
- **B3 — shared borrows `&expr`.** Only if a compiler or library module
  needs them; the parser and the backend must both accept them first.
- **B4 — faster copies for N3.** The backend uses the frontend facts to skip
  retain/release on locals proven `live` and never aliased, and inlines
  per-slot release (ADR-0006, "Consequences"). Requires an ADR-0006 update
  and measurements.
- **B5 — weak references.** Only after the ADR described below.

## Fixtures

- Valid: `MoveSemantics.snl` (moves, string and int copies, argument
  borrow, move then use of the destination).
- Invalid: `InvalidUseAfterMove.snl`, `InvalidConditionalMove.snl`,
  `InvalidFieldMove.snl`, with exact lines and spans asserted in
  `bootstrap-diagnostics`.

## Acceptance criteria

- `make bootstrap-diagnostics` asserts each new error line exactly, as it
  does for `SNV4001`–`SNV4003`; the valid fixture runs with the same stdout
  and exit status on `moil run-snbc` and the Mois executor
  (`make bootstrap-vm`) and natively (`make bootstrap-native`).
- Differential: every fixture has the same accept/reject outcome under
  `moil check` and the seed. A rejection matches when the seed's `SNV5xxx`
  code maps to the reference's `MOISL02xx` code through the table in
  `diagnostics.md`, and the position agrees by that file's rule: the same
  line, and the seed span starts at the byte of the reference column.
- Compiling the compiler's own sources emits no diagnostics;
  `make bootstrap-fixed-point bootstrap-vm-self bootstrap-native-self` pass.
- B1–B2 are analysis only and the emitters are untouched (decision 2): the
  SnBC images of the existing fixtures (for example `hello.snbc`) are
  byte-for-byte unchanged.
- B4 keeps zero live blocks and the constant peak of `nativeMemory`, and
  reports N3 compile time before and after on the same host.

## Reference borrow codes

[snl#8](https://github.com/moislang/moil/pull/8) read the meanings in
`moisc` v0.3.0 (`src/sema/borrow.h`): `MOISL0240` use after move, `0241`
use after drop, `0242` exclusive borrow conflict, `0243` mutation while
shared, `0244` send while borrowed, `0245` null dereference, `0246` static
index out of bounds, `0247` unsound `defer`, `0248` ownership-checker
capacity exceeded, `0249` reference rebound to different places across
branches, `0250` reference rebound across a loop iteration (loop-carried
borrows unsupported), `0251` move out of an array element or field.
`MOISL0400` is the reference SnBC emitter's "cannot lower" error, a back-end
limit rather than an ownership rule. Only `0240` and `0251` are in scope for
B1–B2; `0242`, `0243`, `0249` and `0250` become relevant only with B3.

## Weak references

The reference memory-safety contract (`docs/spec/memory-safety.md` in the
`moisc` checkout, section 2.5) lists `Weak<T>`/`LocalWeak<T>` as
`[PROPOSED — P6]`, built on `Shared<T>` and generics. The seed has no
generics, and no probed `moil` feature provides a weak reference. Before any
implementation, a new ADR must decide the spelling, how `upgrade` reports a
released target, how the runtime counts weak owners (the block header has one
count today, ADR-0006 decision 5), and how the strong-cycle check treats weak
edges.

## Evidence to record

Probe commands and outputs per slice; the diagnostic lines; the
fixture-image hashes before and after (B1–B2); the stage hashes of the fixed
points; for B4, memory reports and timings. Results on Linux are auxiliary
until they are repeated on `aarch64-apple-darwin`.

## Risks

- The separate pass needs the types the emitters compute today
  (`fieldTypeAt` in `Emit.snl`); it must recompute or share them without
  changing emission.
- Being stricter than `moil check` would break the compiler build; being
  looser leaves gaps the backend must still cover dynamically.
- B4 removes dynamic safety nets; a wrong fact becomes a use after free.

## Closed questions

1. **Reassigning a moved `var` local.** Closed on 2026-11-21 by Villa
   (spec owner): the seed follows `moil check` v0.3.0, and Yuri may
   revisit. Probe, `moil` v0.3.0: after `var a = [1, 2, 3]` and
   `var b = a`, the assignment `a = [4]` is
   `error[MOISL0240]: use of a moved value` at the left-hand `a`
   (column 5), even when `a` is not used afterwards. The same code
   fires for an object local (`o = Box { value: 2 }` after `var p = o`).
   If the local is then used (`return a.len()`), `moil check` reports a
   second `MOISL0240` at that use. Assigning to a `let` local is already
   `SNV4005` (snl#7), so this only concerns `var`. The seed reports
   `SNV5001` at the assignment, matching that rule.

## Open questions

2. **Weak references:** is there a concrete need (a cyclic structure in the
   compiler or the library) that justifies the ADR now? (Yuri)
3. **Do loops, methods and `return` match the reference?** B0 must probe
   them; the reference contract does not cover every case in the subset.
4. **Is B3 needed at all** while no compiler module uses `&`?
