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
   spans, the way `snl check` already rejects them: use after move and move
   out of a field or array element.
2. Give the native backend static ownership facts so it can drop dynamic
   counts and use faster copies and release for N3 (ADR-0006).
3. Define the gate that weak references must pass before they enter the
   subset. They are not specified here (see "Weak references").

## Non-goals

- Lifetimes in signatures, `&mut`, raw pointers, `unsafe`, `defer`, tasks
  (`SNOVA0244`, `SNOVA0247`) and nullable references.
- A tracing or cycle collector. Strong cycles stay rejected at run time by
  the native runtime (`nativeCycle`, status 70).
- Changing what the emitters or the backend produce in slices B1–B2: those
  slices only add diagnostics, in a pass of their own.

## Current state

- Ownership is analysed only in the backend, over SnBC stack slots
  (`bootstrap/src/nativeOwnership.snl`, runtime type `Ownership` in
  `bootstrap/runtime/ownership.snl`): each local, temporary, field and
  element holds a count; `LOAD_LOCAL` produces an uncounted borrow until it
  escapes (ADR-0006, decision 6).
- Type checks live inside the emitters (`emitExpr.snl`, `emit.snl`;
  `SNV4001`–`SNV4003` printed by `compiler.snl`). There is no separate
  semantic pass.
- Probes (see `evidence.md`, "probes for the library and borrow-checker
  specifications"), comparing `snl check` v0.3.0 with the seed:

  | Program | `snl check` | Seed |
  |---|---|---|
  | `var b = a` (array), then `a.len()` | `SNOVA0240` | accepts; executors print `3` |
  | move inside an `if`, use after it | `SNOVA0240` | accepts |
  | `var p = o` (object), then `o.value` | `SNOVA0240` | accepts |
  | `var b = a`, then `a = [4]` and `a.len()` | `SNOVA0240` (twice) | accepts |
  | `var taken = holder.items` (field) | `SNOVA0251` | accepts |
  | `take(a)` (array argument), then `a.len()` | accepts | accepts |
  | `var t = s` (string), then `s` | accepts | accepts |
  | `var y = x` (int), then `x` | accepts | accepts |
  | `total(&a)` with parameter `&int[]` | accepts | `SNV2001` at the `&` |

- `bootstrap-check` runs `snl check --project bootstrap/src`, so the compiler
  sources already obey the root's move rules, and they contain no `&`
  expression. A seed check that is a subset of those rules does not reject
  the compiler itself.

## Decisions

Recorded on 2026-11-21, decided by Inhegas (Engineering Lead):

1. **Diagnostic namespace.** The seed keeps its own codes, one block per
   phase. In `bootstrap/src/compiler.snl` today: `SNV1xxx` lexer
   (`SNV1001`), `SNV2xxx` parser (`SNV2001`), `SNV3xxx` lowering
   (`SNV3001`), `SNV4xxx` types (`SNV4001`–`SNV4003`), and `SNW0001` for the
   comparison warning. The borrow checker gets a new block, `SNV5xxx`.
   Reference codes (`SNOVA02xx`) never appear in seed output, so the prefix
   always says which compiler produced an error.
2. **Placement.** The checker is a separate pass between analysis and
   emission, in its own module `bootstrap/src/borrowCheck.snl`. The emitters
   (`emit.snl`, `emitExpr.snl`, `emitStmt.snl`) do not change, which is what
   guarantees the "identical SnBC images" criterion below.

## Proposed surface

Two new errors, each with the binding's byte span, in the format of
`SNV4002`:

| Code | Message |
|---|---|
| `SNV5001` | `use of a moved value at line L, span S..E` |
| `SNV5002` | `cannot move a value out of a field or array element at line L, span S..E` |

Correspondence with the reference, used by the differential:

| Seed | `snl check` v0.3.0 | Meaning |
|---|---|---|
| `SNV5001` | `SNOVA0240` | use of a moved value |
| `SNV5002` | `SNOVA0251` | move out of a field or array element |

No new syntax in B1–B2.

## Semantics (B1–B2)

- **Movable values:** arrays and objects. Ints, bools and strings are
  copied (probes above).
- **Move:** binding or assigning a local of movable type to another local
  (`let`/`var` initializer or assignment). A call argument is not a move:
  `snl check` accepts a use after `take(a)` (probe above).
- **State:** each local is `live`, `moved` or `maybe moved`. A read of a
  `moved` or `maybe moved` local fails with `SNV5001`. At the join of
  `if`/`else` and after a `while` body, a local moved on any path is
  `maybe moved`.
- **Reassignment:** the reference also rejects assigning to a moved local
  (fourth probe row). Whether the seed copies this rule is open question 2.
- **Field and element moves:** binding a field or an array element of
  movable type to a local fails with `SNV5002`. Passing it as a call
  argument stays allowed (SPEC-0001, rule 4).

## Slices

- **B0 — probes.** Done for the table above; extend to `return`, `while`,
  method receivers and struct fields of struct type before B1 starts.
- **B1 — use after move** (`SNV5001`): create `borrowCheck.snl`, add it to
  `ownSource()` in `sourceJoin.snl`, and call it from the driver after
  parsing and before emission; straight-line code first, then `if`/`while`
  joins.
- **B2 — move out of a field or element** (`SNV5002`), in the same pass.
- **B3 — shared borrows `&expr`.** Only if a compiler or library module
  needs them; the parser and the backend must both accept them first.
- **B4 — faster copies for N3.** The backend uses the frontend facts to skip
  retain/release on locals proven `live` and never aliased, and inlines
  per-slot release (ADR-0006, "Consequences"). Requires an ADR-0006 update
  and measurements.
- **B5 — weak references.** Only after the ADR described below.

## Fixtures

- Valid: `moveSemantics.snl` (moves, string and int copies, argument
  borrow, move then use of the destination).
- Invalid: `invalidUseAfterMove.snl`, `invalidConditionalMove.snl`,
  `invalidFieldMove.snl`, with exact lines and spans asserted in
  `bootstrap-diagnostics`.

## Acceptance criteria

- `make bootstrap-diagnostics` asserts each new error line exactly, as it
  does for `SNV4001`–`SNV4003`; the valid fixture runs with the same stdout
  and exit status on `snl run-snbc` and the Snova executor
  (`make bootstrap-vm`) and natively (`make bootstrap-native`).
- Differential: every fixture has the same accept/reject outcome under
  `snl check` and the seed. A rejection matches when the seed's `SNV5xxx`
  code maps to the reference's `SNOVA02xx` code through the correspondence
  table and both point at the same source position (line and span).
- Compiling the compiler's own sources emits no diagnostics;
  `make bootstrap-fixed-point bootstrap-vm-self bootstrap-native-self` pass.
- B1–B2 are analysis only and the emitters are untouched (decision 2): the
  SnBC images of the existing fixtures (for example `hello.snbc`) are
  byte-for-byte unchanged.
- B4 keeps zero live blocks and the constant peak of `nativeMemory`, and
  reports N3 compile time before and after on the same host.

## Weak references

The reference memory-safety contract (`docs/spec/memory-safety.md` in the
`snovac` checkout, section 2.5) lists `Weak<T>`/`LocalWeak<T>` as
`[PROPOSED — P6]`, built on `Shared<T>` and generics. The seed has no
generics, and no probed `snl` feature provides a weak reference. Before any
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
  (`fieldTypeAt` in `emit.snl`); it must recompute or share them without
  changing emission.
- Being stricter than `snl check` would break the compiler build; being
  looser leaves gaps the backend must still cover dynamically.
- B4 removes dynamic safety nets; a wrong fact becomes a use after free.

## Open questions

1. **Reassigning a moved local:** reject it like the reference, or accept it
   as a re-initialisation? (Yuri)
2. **Weak references:** is there a concrete need (a cyclic structure in the
   compiler or the library) that justifies the ADR now? (Yuri)
3. **Do loops, methods and `return` match the reference?** B0 must probe
   them; the reference contract does not cover every case in the subset.
4. **Is B3 needed at all** while no compiler module uses `&`?
5. **The `SNOVA0248`–`SNOVA0250` codes** cited by ADR-0006 (range
   `SNOVA0240`–`0251`) were not found in the reference sources available on
   this host; their meaning needs checking in Yuri's `snovac` checkout.
