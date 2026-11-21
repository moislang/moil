# SPEC-0002 — Frontend borrow checker and weak references

- **Status:** Proposed
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
- Changing what the backend emits in slices B1–B2: those slices only add
  diagnostics.

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

## Proposed surface

Two new semantic errors, numbered after the existing `SNV4001`–`SNV4003`
(proposal; see open question 1), each with the binding's byte span like
`SNV4002`:

| Code | Message | Reference |
|---|---|---|
| `SNV4004` | `use of a moved value at line L, span S..E` | `SNOVA0240` |
| `SNV4005` | `cannot move a value out of a field or array element at line L, span S..E` | `SNOVA0251` |

No new syntax in B1–B2.

## Semantics (B1–B2)

- **Movable values:** arrays and objects. Ints, bools and strings are
  copied (probes above).
- **Move:** binding or assigning a local of movable type to another local
  (`let`/`var` initializer or assignment). A call argument is not a move:
  `snl check` accepts a use after `take(a)` (probe above).
- **State:** each local is `live`, `moved` or `maybe moved`. A read of a
  `moved` or `maybe moved` local fails with `SNV4004`. At the join of
  `if`/`else` and after a `while` body, a local moved on any path is
  `maybe moved`.
- **Reassignment:** the reference also rejects assigning to a moved local
  (fourth probe row). Whether the seed copies this rule is open question 2.
- **Field and element moves:** binding a field or an array element of
  movable type to a local fails with `SNV4005`. Passing it as a call
  argument stays allowed (SPEC-0001, rule 4).

## Slices

- **B0 — probes.** Done for the table above; extend to `return`, `while`,
  method receivers and struct fields of struct type before B1 starts.
- **B1 — use after move** (`SNV4004`), straight-line code first, then
  `if`/`while` joins.
- **B2 — move out of a field or element** (`SNV4005`).
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
  `snl check` and the seed, and the codes map as in the table above.
- Compiling the compiler's own sources emits no diagnostics;
  `make bootstrap-fixed-point bootstrap-vm-self bootstrap-native-self` pass.
- B1–B2 are analysis only: the SnBC images of the existing fixtures (for
  example `hello.snbc`) are byte-for-byte unchanged.
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

- Flow-sensitive state inside the emitters may conflict with the rule that
  semantics and lowering have separate contracts.
- Being stricter than `snl check` would break the compiler build; being
  looser leaves gaps the backend must still cover dynamically.
- B4 removes dynamic safety nets; a wrong fact becomes a use after free.

## Open questions

1. **Codes:** a new `SNV4xxx` block, as proposed, or the reference codes
   `SNOVA0240`/`SNOVA0251` directly? (Inhegas)
2. **Reassigning a moved local:** reject it like the reference, or accept it
   as a re-initialisation? (Yuri)
3. **Where the checker lives:** inside the emitters, like `SNV4001`–`SNV4003`,
   or a new pass over the parsed tree before lowering? (Inhegas)
4. **Do loops, methods and `return` match the reference?** B0 must probe
   them; the reference contract does not cover every case in the subset.
5. **Is B3 needed at all** while no compiler module uses `&`?
6. **Weak references:** is there a concrete need (a cyclic structure in the
   compiler or the library) that justifies the ADR now? (Yuri)
7. **The `SNOVA0248`–`SNOVA0250` codes** cited by ADR-0006 (range
   `SNOVA0240`–`0251`) were not found in the reference sources available on
   this host; their meaning needs checking in Yuri's `snovac` checkout.
