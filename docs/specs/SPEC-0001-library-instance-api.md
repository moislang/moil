# SPEC-0001 — Instance-based library API

- **Status:** Proposed; slice 1 is in review as
  [snl#3](https://github.com/snovalang/snl/pull/3) (draft)
- **Date:** 2026-11-21
- **Phase:** P4, incremental growth
- **Related:** [ADR-0007](../decisions/ADR-0007-object-model.md) (object
  model), [ADR-0006](../decisions/ADR-0006-native-runtime.md) (ownership),
  [`subset.md`](../roadmap/subset.md) (Library row)

## Goal

Let code built by `snl build` v0.3.0, the current root, use the data
structures in `bootstrap/library/`, so that a compiler module can depend on
them before the native compiler (N3) replaces the root. Every library fixture
must keep its current stdout and exit status on `snl run-snbc`, on the Snova
executor and natively.

## Non-goals

- New data structures, generics or a standard-library layout.
- Changes to the seed's language subset: the seed already accepts every
  construct used here (fieldless classes, instance methods, positional
  constructors).
- Changes to the native runtime types in `bootstrap/runtime/`, which keep
  their static methods (ADR-0007, decision 2).
- Relaxing the ADR-0007 rules; that waits for a new root (ADR-0007, "Reopen
  when").

## Current state

- `bootstrap/library/` holds `BinarySearch`, `LinearSearch`, `Sorting`
  (stateless, static methods), `IntCell`, `IntArray`, `MapEntry`, `TreeNode`
  (state plus static accessors), and `BinaryHeap`, `BinaryTree`, `IntMap`
  (instance methods over those types).
- `make bootstrap-library` joins each fixture (`librarySearch`,
  `librarySorting`, `libraryBinaryHeap`, `libraryBinaryTree`,
  `libraryIntMap`) with the library, compiles it with the seed, and compares
  `snl run-snbc`, the Snova executor and the native executable (zero live
  blocks). `snl build` never compiles the library.
- The root rejects the current library. Probes (see `evidence.md`,
  "probes for the library and borrow-checker specifications"):
  - every fixture fails `snl build` with `invalid SnBC unit for native
    compilation` (static methods);
  - `BinaryHeap` fails first with `SNOVA0400 cannot lower call to SnBC`,
    because it calls methods on a local alias of its `storage` field;
  - `let cell = cells[index]` inside a method is rejected by `snl check` with
    `SNOVA0251` (move out of an array element or field). The seed also
    rejected that probe, with `SNV3001` at the line of `main`'s `return`;
    lowering lines are not exact yet, so the cause is unconfirmed.
- The fixtures create objects with literals (`IntMap { ... }`,
  `BinaryHeap { storage: IntArray { ... } }`), and the root rejects method
  calls on literal-created objects (ADR-0007).

## Proposed surface

The API follows ADR-0007, decision 3. For every library type:

1. **No static methods.** Stateless types become fieldless classes created
   with `Type()`; sibling calls drop the type qualifier
   (`lowerBound(...)`, not `BinarySearch.lowerBound(...)`).
2. **Positional constructors.** Fixtures and callers create objects with
   `Type(args)`, never with `Type { ... }`, and keep them in locals or
   parameters.
3. **No method calls on fields.** A type that needs a collaborator either
   owns its storage directly (for example, `cells: IntCell[]` and `size`) or
   receives the collaborator as a typed parameter.
4. **Element access through a typed parameter.** A method that needs an
   array element passes it to a sibling method or function that takes it as
   a typed parameter (`readCell(cells[index])`), instead of binding it to a
   local. A probe of this pattern (class `Pool` with `cells: Cell[]` and
   private `readCell(cell: Cell)` / `assignCell(cell: Cell, newValue: int)`)
   passed `snl build`, and the executable, `snl run-snbc` on the seed's image
   and the Snova executor all printed `11 20 2` with exit 0.
5. **No method named like an array builtin** and **no array shared by two
   fields** (ADR-0007). The probe above showed that `append`, `at`, `put` and
   `count` are not intercepted by the root.

No new diagnostics: the seed's codes do not change, and the root's existing
errors (`invalid SnBC unit for native compilation`, `SNOVA0400`, `SNOVA0251`)
are the negative evidence that a module is not yet migrated.

## Slices

Each slice migrates whole modules, moves their fixture into
`LIBRARY_ROOT_FIXTURES`/`LIBRARY_ROOT_SOURCES` (introduced by snl#3) and keeps
the fixture's expected stdout and exit status.

1. **Stateless searches** — snl#3: `BinarySearch`, `LinearSearch`;
   fixture `librarySearch` (exit 53); new target `make bootstrap-library-root`.
2. **`Sorting`**: `sorted`, `isSorted` and the private `sortRange` become
   instance methods; fixture `librarySorting`.
3. **`IntCell` and `IntArray`**: `IntCell.read`/`assign` become instance
   methods; `IntArray` reaches its cells through rule 4. Add a dedicated
   fixture `libraryIntArray` (today `IntArray` is only covered through
   `libraryBinaryHeap`), including out-of-range `at`/`put` and
   `removeLast` on an empty array.
4. **`BinaryHeap`**: remove the `let store = storage` calls (rule 3);
   fixture `libraryBinaryHeap` with a positional constructor.
5. **`TreeNode`/`BinaryTree` and `MapEntry`/`IntMap`**: accessors become
   instance methods reached through rule 4; constructors are positional;
   fixtures `libraryBinaryTree` and `libraryIntMap`.
6. **First compiler use**: one compiler module uses a migrated type, and the
   static API is gone (`LIBRARY_ROOT_*` equals `LIBRARY_*`).

## Acceptance criteria

For every slice:

- `make bootstrap-library-root` passes for the migrated fixtures: the
  `snl build` executable, `snl run-snbc` on the seed's image and the Snova
  executor agree on stdout and exit status.
- The migrated fixture's stdout and exit status equal the values before the
  migration (recorded in `evidence.md`).
- `make bootstrap-library` passes for all five fixtures, including the native
  half on `aarch64-apple-darwin` with zero live blocks at exit.
- `make bootstrap-fixed-point bootstrap-vm` pass; `make bootstrap-native` is
  run on the Mac as a regression check.
- `subset.md` (Library row), ADR-0007 consequences and `evidence.md` are
  updated in the same change.

Slice 6 additionally requires `make bootstrap-fixed-point`,
`make bootstrap-vm-self` and `make bootstrap-native-self` with the library
inside the compiler sources, and records the new stage hashes.

## Evidence to record

Per slice: revision, host, `snl` version and binary or archive hash, the
commands above, stdout/exit per engine, the SHA-256 of each
`<fixture>.root.snbc`, and what was not run (the native half on Linux).
Linux results are auxiliary until the Mac run: the `snl v0.3.0` Linux C VM
miscompares some `x == false` expressions (see `evidence.md`), so the Snova
executor is the independent side of the differential there.

## Adjustments suggested for snl#3

- Name this specification in the PR description and in the ADR-0007
  consequence, so slices 2–6 have a single plan.
- Record, in the evidence entry, that a field alias call is rejected with
  `SNOVA0400` and that `let x = array[i]` is rejected with `SNOVA0251`; slices
  3–5 depend on both facts.
- Keep the comparison against the pre-migration output inside the gate (for
  example, a committed expected-output file per fixture), so the claim
  "output unchanged" does not depend on a manual run.

## Risks

- Fieldless objects and the rule-4 pattern have not run natively yet; the
  Mac run of slice 1 covers the first case.
- Rule 4 adds a call per element access; slices 3–5 can make `IntMap` and
  `BinaryTree` slower on the SnBC executors. Measure before and after.
- The Linux C VM defect can hide a divergence between the root executable
  and `run-snbc`, because both use the same C VM.

## Open questions

1. **Stateful collaborators (slice 4):** should `BinaryHeap` own
   `cells`/`size` directly or receive an `IntArray` parameter per call? The
   first keeps the API small; the second keeps `IntArray` reusable.
2. **How the compiler links the library (slice 6):** a package import
   resolved by `snl build --project`, or an entry in the internal assembly
   (`sourceJoin.snl`)? The seed does not resolve general imports yet.
3. **Which compiler module is the first user** (for example, a map in name
   resolution), and does it need a non-int key type, which the library does
   not offer?
4. **Full list of array builtin names** the root intercepts (ADR-0007 lists
   `push`, `pop`, `len`, `get`, ...): needs a probe before slices 3–5 name
   new methods.
