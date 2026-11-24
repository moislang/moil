# SPEC-0001 — Instance-based library API

- **Status:** Accepted; source API and domain layout updated; full differential validation pending; linking and first-stage visibility decided; slice 1 merged as
  [snl#3](https://github.com/moislang/moil/pull/3) and slice 2 merged as
  [snl#10](https://github.com/moislang/moil/pull/10)
- **Date:** 2026-11-21
- **Phase:** P4, incremental growth
- **Related:** [ADR-0007](../decisions/ADR-0007-object-model.md) (object
  model), [ADR-0006](../decisions/ADR-0006-native-runtime.md) (ownership),
  [`subset.md`](../roadmap/subset.md) (Library row)

## Goal

Let code built by `moil build` v0.3.0, the current root, use the data
structures in `bootstrap/library/`, so that a compiler module can depend on
them before the native compiler (N3) replaces the root. Every library fixture
must keep its current stdout and exit status on `moil run-snbc`, on the Mois
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

- `bootstrap/library/` is organized into cohesive packages:
  `algorithms/search`, `algorithms/sorting`, `collections/array`,
  `collections/heap`, `collections/tree`, and `collections/map`.
- Public library types use instance methods. `BinaryTree` and `IntMap` are
  aggregate roots that own their node and entry arenas; `TreeNode` and
  `MapEntry` provide entity behavior. Their constructors use positional
  arguments. The root-compatible source list and fixture join order preserve
  the package folders in the staged project.
- `make bootstrap-library` joins each fixture (`librarySearch`,
  `librarySorting`, `libraryIntArray`, `libraryBinaryHeap`,
  `libraryBinaryTree`, `libraryIntMap`) with the library, compiles it with the seed, and compares
  `moil run-snbc`, the Mois executor and the native executable (zero live
  blocks). `make bootstrap-library-root` is being expanded to compile all six
  fixtures with the root compiler as well.
- The previous root rejected several pre-migration APIs. Probes (see
  `evidence.md`, "probes for the library and borrow-checker specifications"):
- the pre-migration fixtures failed `moil build` with `invalid SnBC unit for
  native compilation` (static methods);
  - `BinaryHeap` fails first with `MOISL0400 cannot lower call to SnBC`,
    because it calls methods on a local alias of its `storage` field;
  - `let cell = cells[index]` inside a method is rejected by `moil check` with
    `MOISL0251` (move out of an array element or field). The seed rejects
    it one statement later, with `SNV3001` on the first use of the moved
    local, whose type is unknown; the gap inventory in
    [snl#8](https://github.com/moislang/moil/pull/8) explains this and fixes
    the `SNV3001` line, which used to point at the end of the input.
  - A method call through a local alias of a field is accepted by
    `moil check` and by the seed, but `moil build` fails with `MOISL0400`, the
    reference SnBC emitter's "cannot lower" error (snl#8). Only the root
    build enforces this rule, so the library gates must run `moil build`.
- The migrated fixtures create aggregates with positional constructors and
  keep them in locals. The new root-compatible and differential gates still
  need to be run and recorded before this migration is considered complete.

## Decisions

Recorded on 2026-11-21, decided by Inhegas (Engineering Lead):

1. **Linking the library into the compiler.** The compiler gets the library
   through `bootstrap/src/SourceJoin.moi`, the path it already uses to
   assemble its own sources: `ownSource()` appends each library file with
   `appendFile`, in dependency order (the seed resolves a field type only
   when its class was declared earlier, as noted in the `Makefile`). The
   compiler does not use a package import for the library, because general
   import resolution in the seed has no owner in the backlog.
2. **How the first stage sees the library** (decided by Inhegas, based on
   Mike's probe in [snl#6](https://github.com/moislang/moil/pull/6), branch
   `mike/probe-library-root-visibility`). `moil build --project bootstrap/src`
   does not see `bootstrap/library/`, and `moil` v0.3.0 rejects several
   project roots or input files (`MOISL0050 package not found`). It also
   lowers every visible module, used or not: with all of master's
   `bootstrap/library/` visible, every route failed (19 × `MOISL0400` on
   calls, plus field and assignment lowering errors). For slices 2–6 the
   first stage therefore builds from a staging directory generated under
   `build/`, holding `bootstrap/src/*.moi` plus an explicit list of the
   library modules already migrated. The list grows one slice at a time and
   keeps the same order as `ownSource()` in `SourceJoin.moi`. Until slice 6
  the compiler does not call the library, so no gate (neither the fixed point
  nor `bootstrap-library-root`) detects a divergence between the two lists;
  review keeps them in the same order. Slice 6 must add that guarantee, through
  fixed-point coverage or an explicit check. In the probe, the staging directory
   with the two instance searches of snl#3 built, and the self-compilation
   image stayed `8cb80e98…f730ad`, equal to the baseline. Alternatives
   rejected for now: a symbolic link (exposes the whole library, unreliable
   on Windows checkouts) and a path dependency (`moil get`, which adds
   `mod.sns`/`mod.lock` and a cache in `$MOIS_HOME`, and also exposes every
   module). Probe the path dependency again once every module is migrated.

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
   passed `moil build`, and the executable, `moil run-snbc` on the seed's image
   and the Mois executor all printed `11 20 2` with exit 0.
5. **No method named like an array builtin** and **no array shared by two
   fields** (ADR-0007). The probe above showed that `append`, `at`, `put` and
   `count` are not intercepted by the root.

No new diagnostics: the seed's codes do not change, and the root's existing
errors (`invalid SnBC unit for native compilation`, `MOISL0400`, `MOISL0251`)
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
   `removeLast` on an empty array. API shape (probed with `moil check`,
   `moil build`, `moil run-snbc` and the Mois executor): `IntCell(value)`
   with instance `read()`/`assign(newValue)`; `IntArray(cells, 0)` keeps its
   instance methods and reaches cells through the private siblings
   `readCell(cell: IntCell)` and `assignCell(cell: IntCell, newValue)`.
   `IntMap` bucket heads and entries use the same typed-parameter helper
   pattern (`readHead`/`assignHead`, `entryKey`/`entryValue`/`entryNext` and
   `replaceEntryValue`) because array elements cannot be method receivers.
   `count`, `isEmpty`, `at`, `put`,
   `append`, `removeLast`, `swap` and `values` are not intercepted as array
   builtins by `moil build` v0.3.0.
4. **`BinaryHeap`**: remove the `let store = storage` calls (rule 3), route
   collaborator operations through typed helpers, and use a positional
   constructor; fixture `libraryBinaryHeap`.
5. **`TreeNode`/`BinaryTree` and `MapEntry`/`IntMap`**: entity behavior uses
   instance methods reached through typed aggregate helpers; constructors are
   positional; fixtures `libraryBinaryTree` and `libraryIntMap`.
6. **First compiler use**: the migrated library files are added to
   `ownSource()` in `SourceJoin.moi` (decision 1) and to the staging list
   (decision 2), one compiler module uses a migrated type, and the static API is gone (`LIBRARY_ROOT_*` equals
   `LIBRARY_*`).

## Acceptance criteria

Artifacts are compared as SnBC images, never as `moil build` executables
(see "Known issue" below). The executable is only run, and its stdout and
exit status are compared.

For every slice:

- `make bootstrap-library-root` passes for the migrated fixtures: the
  `moil build` executable, `moil run-snbc` on the seed's image and the Mois
  executor agree on stdout and exit status.
- The migrated fixture's stdout and exit status equal the values before the
  migration (recorded in `evidence.md`).
- `make bootstrap-library` passes for all six fixtures, including the native
  half on `aarch64-apple-darwin` with zero live blocks at exit.
- `make bootstrap-fixed-point bootstrap-vm` pass; `make bootstrap-native` is
  run on the Mac as a regression check.
- `subset.md` (Library row), ADR-0007 consequences and `evidence.md` are
  updated in the same change.
- The directory/package map and aggregate responsibilities are documented in
  [`library-domains.md`](../architecture/library-domains.md).

From slice 2 on, `make bootstrap-build` builds from the staging directory
(decision 2), and the stage1 SnBC image does not change while the compiler
does not call the library. Slice 6 additionally requires
`make bootstrap-fixed-point`, `make bootstrap-vm-self` and
`make bootstrap-native-self` with the library inside the compiler sources,
and records the new stage hashes.

**Known issue.** Two `moil build` runs on the same inputs produce executables
that differ by one byte, baseline included, while the SnBC images are
identical (snl#6). Until executable reproducibility is solved, together with
the Mach-O reproducibility and normalization gate in `subset.md`, only SnBC
hashes count as evidence. The Linux x86-64 CI runner in preparation also
compares only SnBC images (stage1 against stage2 with `cmp`).

## Evidence to record

Per slice: revision, host, `moil` version and binary or archive hash, the
commands above, stdout/exit per engine, the SHA-256 of each
`<fixture>.root.mlbc` and of stage1 (never of an executable), the staging
list used, and what was not run (the native half on Linux).
Linux results are auxiliary until the Mac run: the `moil v0.3.0` Linux C VM
miscompares some `x == false` expressions (see `evidence.md`), so the Mois
executor is the independent side of the differential there.

## Adjustments suggested for snl#3

- Name this specification in the PR description and in the ADR-0007
  consequence, so slices 2–6 have a single plan.
- Record, in the evidence entry, that a field alias call is rejected with
  `MOISL0400` and that `let x = array[i]` is rejected with `MOISL0251`; slices
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
2. **Which compiler module is the first user** (for example, a map in name
   resolution), and does it need a non-int key type, which the library does
   not offer?
3. **Full list of array builtin names** the root intercepts (ADR-0007 lists
   `push`, `pop`, `len`, `get`, ...): needs a probe before slices 3–5 name
   new methods.
